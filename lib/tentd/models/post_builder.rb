module TentD
  module Model

    module PostBuilder
      extend self

      CreateFailure = Post::CreateFailure

      def build_attributes(env, options = {})
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

        if options[:import]
          attrs.merge!(
            :entity_id => Entity.first_or_create(data['entity']).id,
            :entity => data['entity']
          )
        elsif options[:entity]
          attrs.merge!(
            :entity_id => Entity.first_or_create(options[:entity]).id,
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
        elsif options[:version]
          unless options[:notification]
            raise CreateFailure.new("Parent version not specified")
          end
        end

        if TentType.new(attrs[:type]).base == %(https://tent.io/types/meta)
          # meta post is always public
          attrs[:public] = true
        else
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
              next memo unless attachment.has_key?('digest')
              if attachment['model'] = Attachment.where(:digest => attachment['digest']).first
                memo << attachment
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

        attrs
      end

      def create_delete_post(post, options = {})
        ref = { 'entity' => post.entity, 'post' => post.public_id }
        ref['version'] = post.version if options[:version]

        create_from_env(
          'current_user' => post.user,
          'data' => {
            'type' => 'https://tent.io/types/delete/v0#',
            'refs' => [ ref ]
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
        attrs = build_attributes(env, options)

        if TentType.new(env['data']['type']).base == %(https://tent.io/types/subscription)
          if options[:notification]
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

          import_results = RelationshipImporter.import(env['current_user'], attrs)
          post = import_results.post
        else
          post = Post.create(attrs)
        end

        case TentType.new(post.type).base
        when %(https://tent.io/types/app)
          App.update_or_create_from_post(post, :create_credentials => !options[:import])
        when %(https://tent.io/types/app-auth)
          if options[:import] && (m = post.mentions.find { |m| TentType.new(m['type']).base == %(https://tent.io/types/app) })
            App.update_app_auth(post, m['post'])
          end
        when %(https://tent.io/types/credentials)
          if options[:import]
            if m = post.mentions.find { |m| TentType.new(m['type']).base == %(https://tent.io/types/app) }
              App.update_credentials(post, m['post'])
            elsif m = post.mentions.find { |m| TentType.new(m['type']).base == %(https://tent.io/types/app-auth) }
              App.update_app_auth_credentials(post, m['post'])
            end
          end
        end

        if options[:notification] && TentType.new(post.type).base == %(https://tent.io/types/delete)
          delete_from_notification(env, post)
        end

        if TentType.new(post.type).base == %(https://tent.io/types/meta)
          env['current_user'].update_meta_post_id(post)
          Relationship.update_meta_post_ids(post)
        end

        if Array === env['data']['mentions']
          post.create_mentions(env['data']['mentions'])
        end

        unless options[:notification]
          if Array === env['data']['attachments']
            env['data']['attachments'].each do |attachment|
              PostsAttachment.create(
                :attachment_id => attachment['model'].id,
                :content_type => attachment['content_type'],
                :post_id => post.id
              )
            end
          end

          if Array === env['attachments']
            post.create_attachments(env['attachments'])
          end
        end

        if Array === attrs[:version_parents]
          post.create_version_parents(attrs[:version_parents])
        end

        if !options[:notification] && !options[:import] && options[:deliver_notification] != false
          post.queue_delivery
        end

        post
      end

      def create_attachments(post, attachments)
        attachments.each_with_index do |attachment, index|
          data = attachment[:tempfile].read
          attachment[:tempfile].rewind

          PostsAttachment.create(
            :attachment_id => Attachment.find_or_create(
              TentD::Utils::Hash.slice(post.attachments[index], 'digest', 'size').merge(:data => data)
            ).id,
            :post_id => post.id,
            :content_type => attachment[:content_type]
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
