module TentD
  module Model

    module PostBuilder
      extend self

      CreateFailure = Post::CreateFailure

      def build_attributes(env, options = {})
        TentD.logger.debug "PostBuilder.build_attributes" if TentD.settings[:debug]

        data = env['data']
        current_user = env['current_user']
        type, base_type = Type.find_or_create(data['type'])

        unless type
          raise CreateFailure.new("Invalid type: #{data['type'].inspect}")
        end

        received_at_timestamp = (options[:import] && data['received_at']) ? data['received_at'] : TentD::Utils.timestamp
        published_at_timestamp = (data['published_at'] || received_at_timestamp).to_i

        if data['version']
          version_published_at_timestamp = data['version']['published_at'] || published_at_timestamp
          version_received_at_timestamp = (options[:import] && data['version']['received_at']) ? data['version']['received_at'] : received_at_timestamp
        else
          version_published_at_timestamp = published_at_timestamp
          version_received_at_timestamp = received_at_timestamp
        end

        attrs = {
          :user_id => current_user.id,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => version_published_at_timestamp,
          :version_received_at => version_received_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => received_at_timestamp,

          :content => data['content'],
        }

        if options[:notification] || options[:import]
          if data['app']
            attrs[:app_name] = data['app']['name']
            attrs[:app_url] = data['app']['url']
            attrs[:app_id] = data['app']['id'] if options[:import]
          end
        elsif _app = Authorizer.new(env).app_json
          attrs[:app_name] = _app[:name]
          attrs[:app_url] = _app[:url]
          attrs[:app_id] = _app[:id]
        end

        if options[:import]
          attrs.merge!(
            :entity_id => Entity.first_or_create(data['entity']).id,
            :entity => data['entity']
          )

          attrs[:original_entity] = data['original_entity'] if data['original_entity']
        elsif options[:entity]
          attrs.merge!(
            :entity_id => options[:entity_id] || Entity.first_or_create(options[:entity]).id,
            :entity => options[:entity]
          )
        else
          attrs.merge!(
            :entity_id => current_user.entity_id,
            :entity => current_user.entity,
          )
        end

        if options[:public_id]
          attrs[:public_id] = options[:public_id]
        end

        if data['version'] && Array === data['version']['parents']
          attrs[:version_parents] = data['version']['parents']
          attrs[:version_parents].each_with_index do |item, index|
            unless item['version']
              raise CreateFailure.new("/version/parents/#{index}/version is required")
            end

            unless item['post']
              if options[:public_id]
                item['post'] = attrs[:public_id]
              else
                raise CreateFailure.new("/version/parents/#{index}/post is required")
              end
            end
          end
        elsif options[:public_id]
          unless options[:import] || options[:notification]
            raise CreateFailure.new("Parent version not specified")
          end
        end

        if TentType.new(attrs[:type]).base == %(https://tent.io/types/meta)
          # meta post is always public
          attrs[:public] = true
        else
          if Authorizer.new(env).can_set_permissions?
            if Hash === data['permissions']
              if data['permissions']['public'] == true
                attrs[:public] = true
              else
                attrs[:public] = false

                if Array === data['permissions']['entities']
                  attrs[:permissions_entities] = data['permissions']['entities']
                end
              end
            else
              attrs[:public] = true
            end
          else
            attrs[:public] = false
          end
        end

        if Array === data['mentions'] && data['mentions'].any?
          attrs[:mentions] = data['mentions'].map do |m|
            m['entity'] = attrs[:entity] unless m.has_key?('entity')
            m
          end
        end

        if Array === data['refs'] && data['refs'].any?
          attrs[:refs] = data['refs'].map do |ref|
            ref['entity'] = attrs[:entity] unless ref.has_key?('entity')
            ref
          end
        end

        if options[:notification]
          attrs[:attachments] = data['attachments'] if Array === data['attachments']
        else
          if Array === data['attachments']
            data['attachments'] = data['attachments'].inject([]) do |memo, attachment|
              raise CreateFailure.new("Unknown attachment: #{Yajl::Encoder.encode(attachment)}") unless attachment.has_key?('digest')
              if model = Attachment.find_by_digest(attachment['digest'])
                attachment['model'] = model
                memo << attachment
              else
                raise CreateFailure.new("Unknown attachment: #{Yajl::Encoder.encode(attachment)}")
              end
              memo
            end

            attrs[:attachments] = data['attachments'].map do |attachment|
              {
                :digest => attachment['digest'],
                :size => attachment['model'].size,
                :name => attachment['name'],
                :category => attachment['category'],
                :content_type => attachment['content_type']
              }
            end
          end

          if Array === env['attachments']
            attrs[:attachments] = env['attachments'].inject(attrs[:attachments] || Array.new) do |memo, attachment|
              memo << {
                :digest => TentD::Utils.hex_digest(attachment[:tempfile]),
                :size => attachment[:tempfile].size,
                :name => attachment[:name],
                :category => attachment[:category],
                :content_type => attachment[:content_type]
              }
              memo
            end
          end
        end

        if (Hash === data['version']) && data['version']['id']
          canonical_json = TentCanonicalJson.encode(Post.new(attrs).as_json)
          expected_version = Utils.hex_digest(canonical_json)
          attrs[:version] = data['version']['id']
          unless attrs[:version] == expected_version
            raise CreateFailure.new("Invalid version id. Got(#{Yajl::Encoder.encode(attrs[:version])}), Expected(#{expected_version}) #{canonical_json}")
          end
        end

        attrs
      end

      def create_delete_post(post, options = {})
        ref = { 'entity' => post.entity, 'post' => post.public_id }
        ref['version'] = post.version if options[:version]

        create_from_env(
          'current_user' => post.user,
          'data' => {
            'type' => 'https://tent.io/types/delete/v0#',
            'refs' => [ ref ],
            'mentions' => post.mentions.to_a
          }
        )
      end

      def delete_from_notification(env, post)
        post_conditions = post.refs.to_a.inject({}) do |memo, ref|
          next memo unless !ref['entity'] || ref['entity'] == post.entity

          memo[ref['post']] ||= []
          memo[ref['post']] << ref['version'] if ref['version']

          memo
        end.inject([]) do |memo, (public_id, versions)|
          memo << if versions.any?
            { :public_id => public_id, :version => versions }
          else
            { :public_id => public_id }
          end

          memo
        end

        q = Post.where(:user_id => env['current_user'].id, :entity_id => post.entity_id)
        q = q.where(Sequel.|(*post_conditions))

        q.all.to_a.each do |post|
          delete_opts = { :create_delete_post => false }
          delete_opts[:version] = !!post_conditions.find { |c| c[:public_id] == post.public_id }[:version]
          post.destroy(delete_opts)
        end
      end

      def create_from_env(env, options = {})
        TentD.logger.debug "PostBuilder.create_from_env with options: #{options.inspect}" if TentD.settings[:debug]

        attrs = build_attributes(env, options)

        TentD.logger.debug "PostBuilder.build_attributes done" if TentD.settings[:debug]

        if TentType.new(env['data']['type']).base == %(https://tent.io/types/subscription)
          TentD.logger.debug "PostBuilder.create_from_env: subscription post" if TentD.settings[:debug]

          if options[:notification]
            TentD.logger.debug "PostBuilder.create_from_env: notification" if TentD.settings[:debug]

            subscription = Subscription.create_from_notification(env['current_user'], attrs, env['current_auth.resource'])
            post = subscription.post
          else
            subscription = Subscription.find_or_create(attrs)
            post = subscription.post

            if subscription.deliver == false
              # this will happen as part of the relaitonship init job
              options[:deliver_notification] = false
            end
          end
        elsif options[:import] &&
          (
            TentType.new(attrs[:type]).base == %(https://tent.io/types/relationship) ||
            (TentType.new(attrs[:type]).base == %(https://tent.io/types/credentials) &&
              attrs[:mentions].any? { |m|
                TentType.new(m['type']).base == %(https://tent.io/types/relationship)
              })
          )
          # is a relationship post or credentials mentioning one

          TentD.logger.debug "PostBuilder.create_from_env -> RelationshipImporter.import" if TentD.settings[:debug]

          import_results = RelationshipImporter.import(env['current_user'], attrs)
          post = import_results.post
        else
          TentD.logger.debug "PostBuilder.create_from_env -> Post.create" if TentD.settings[:debug]

          post = Post.create(attrs)
        end

        TentD.logger.debug "PostBuilder.create_from_env: post created: #{post ? post.id : nil.inspect}" if TentD.settings[:debug]

        case TentType.new(post.type).base
        when %(https://tent.io/types/app)
          TentD.logger.debug "PostBuilder.create_from_env -> App.update_or_create_from_post" if TentD.settings[:debug]

          App.update_or_create_from_post(post, :create_credentials => !options[:import])
        when %(https://tent.io/types/app-auth)
          TentD.logger.debug "PostBuilder.create_from_env: app-auth" if TentD.settings[:debug]

          if options[:import] && (m = post.mentions.find { |m| TentType.new(m['type']).base == %(https://tent.io/types/app) })
            TentD.logger.debug "PostBuilder.create_from_env -> App.update_app_auth" if TentD.settings[:debug]

            App.update_app_auth(post, m['post'])
          end
        when %(https://tent.io/types/credentials)
          TentD.logger.debug "PostBuilder.create_from_env: credentials" if TentD.settings[:debug]

          if options[:import]
            TentD.logger.debug "PostBuilder.create_from_env: import" if TentD.settings[:debug]

            if m = post.mentions.find { |m| TentType.new(m['type']).base == %(https://tent.io/types/app) }
              TentD.logger.debug "PostBuilder.create_from_env -> App.update_credentials" if TentD.settings[:debug]

              App.update_credentials(post, m['post'])
            elsif m = post.mentions.find { |m| TentType.new(m['type']).base == %(https://tent.io/types/app-auth) }
              TentD.logger.debug "PostBuilder.create_from_env -> App.update_app_auth_credentials" if TentD.settings[:debug]

              App.update_app_auth_credentials(post, m['post'])
            end
          end
        end

        if options[:notification] && TentType.new(post.type).base == %(https://tent.io/types/delete)
          TentD.logger.debug "PostBuilder.create_from_env -> PostBuilder.delete_from_notification" if TentD.settings[:debug]

          delete_from_notification(env, post)
        end

        if TentType.new(post.type).base == %(https://tent.io/types/meta)
          TentD.logger.debug "PostBuilder.create_from_env -> User(#{env['current_user'].id})#update_meta_post_id" if TentD.settings[:debug]

          env['current_user'].update_meta_post_id(post)

          TentD.logger.debug "PostBuilder.create_from_env -> Relationship.update_meta_post_ids" if TentD.settings[:debug]

          Relationship.update_meta_post_ids(post)
        end

        if Array === env['data']['mentions']
          TentD.logger.debug "PostBuilder.create_from_env -> Post(#{post.id})#create_mentions" if TentD.settings[:debug]

          post.create_mentions(env['data']['mentions'])
        end

        unless options[:notification]
          if Array === env['data']['attachments']
            env['data']['attachments'].each do |attachment|
              TentD.logger.debug "PostBuilder.create_from_env -> PostsAttachment.create" if TentD.settings[:debug]

              PostsAttachment.create(
                :attachment_id => attachment['model'].id,
                :content_type => attachment['content_type'],
                :post_id => post.id
              )
            end
          end

          if Array === env['attachments']
            TentD.logger.debug "PostBuilder.create_from_env -> Post(#{post.id})#create_attachments" if TentD.settings[:debug]

            post.create_attachments(env['attachments'])
          end
        end

        if Array === attrs[:version_parents]
          TentD.logger.debug "PostBuilder.create_from_env -> Post(#{post.id})#create_version_parents" if TentD.settings[:debug]

          post.create_version_parents(attrs[:version_parents])
        end

        if !options[:notification] && !options[:import] && options[:deliver_notification] != false
          TentD.logger.debug "PostBuilder.create_from_env -> Post(#{post.id})#queue_delivery" if TentD.settings[:debug]

          post.queue_delivery
        end

        post
      end

      def create_attachments(post, attachments)
        attachments.each_with_index do |attachment, index|
          attrs = Utils::Hash.slice(
            Utils::Hash.symbolize_keys(post.attachments[index]), :digest, :size
          ).merge(:data => attachment[:tempfile])
          attachment_record = Attachment.find_or_create(attrs)

          PostsAttachment.create(
            :digest => attachment_record.digest,
            :content_type => attachment[:content_type],
            :attachment_id => attachment_record.id,
            :post_id => post.id
          )
        end
      end

      def create_mentions(post, mentions)
        mentions.map do |mention|
          mention_attrs = {
            :user_id => post.user_id,
            :post_id => post.id
          }

          if mention['entity']
            mention_attrs[:entity_id] = Entity.first_or_create(mention['entity']).id
            mention_attrs[:entity] = mention['entity']
          else
            mention_attrs[:entity_id] = post.entity_id
            mention_attrs[:entity] = post.entity
          end

          if mention['type']
            mention_attrs[:type_id] = Type.find_or_create_full(mention['type']).id
            mention_attrs[:type] = mention['type']
          end

          mention_attrs[:post] = mention['post'] if mention.has_key?('post')
          mention_attrs[:public] = mention['public'] if mention.has_key?('public')

          Mention.create(mention_attrs)
        end
      end

      def create_version_parents(post, version_parents)
        version_parents.each do |item|
          item['post'] ||= post.public_id
          _parent = Post.where(:user_id => post.user_id, :public_id => item['post'], :version => item['version']).first
          Parent.create(
            :post_id => post.id,
            :parent_post_id => _parent ? _parent.id : nil,
            :version => item['version'],
            :post => item['post']
          )
        end
      end

    end

  end
end
