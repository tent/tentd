module TentD
  class API
    class Posts
      include Router

      class GetActualId < Middleware
        def action(env)
          id_mapping = [:post_id, :since_id, :before_id, :until_id].select { |key| env.params.has_key?(key) }.inject({}) { |memo, key|
            memo[env.params[key]] = key
            env.params[key] = nil
            memo
          }
          return env unless id_mapping.keys.any?
          posts = Model::Post.unfiltered.select(:id, :public_id, :entity).where(:user_id => Model::User.current.id, :public_id => id_mapping.keys).all
          id_mapping.each_pair do |public_id, key|
            entity = env.params["#{key}_entity"]
            entity ||= env['tent.entity']
            env.params[key] = posts.find { |p|
              p.public_id == public_id && (entity.nil? || p.entity == entity)
            }
            env.params[key] = env.params[key].id if env.params[key]
          end
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if authorize_env?(env, @options[:required_scope])
            q = Model::Post.where(:id => env.params.post_id)

            unless env.current_auth.post_types.include?('all')
              q = q.where(:type_base => env.current_auth.post_types.map { |t| TentType.new(t).base })
            end

            if env.params.version
              q = q.select(:id)
            end

            post = q.first
          else
            post = Model::Post.find_with_permissions(env.params.post_id, env.current_auth)
          end
          if post
            if env.params.version
              if post_version = post.versions_dataset.first(:version => env.params.version.to_i)
                post = post_version
              else
                post = nil
              end
            end

            env.response = post
          end
          env
        end
      end

      class GetCount < Middleware
        def action(env)
          env.params.return_count = true
          env
        end
      end

      class GetFeed < Middleware
        def action(env)
          env.params.delete('post_id')
          if env.stream_requested
            env.start_post_stream = true
          else
            if authorize_env?(env, :read_posts)
              if env.params.return_count && !env.params.mentioned_entity
                env.params.original = true
              end
              env.response = Model::Post.fetch_all(env.params, env.current_auth)
            else
              env.response = Model::Post.fetch_with_permissions(env.params, env.current_auth)
            end
          end
          env
        end
      end

      class CountHeader < API::CountHeader
        def get_count(env)
          GetFeed.new(@app).call(env)
        end
      end

      class PaginationHeader < API::PaginationHeader
        private

        def build_next_params(env)
          params = super
          resource = env.response.last

          params["#{next_id_key(env)}_entity"] = resource.entity
          params
        end

        def build_prev_params(env)
          params = super
          resource = env.response.first

          params["#{prev_id_key(env)}_entity"] = resource.entity
          params
        end

        def clone_params(env)
          params = super
          params.delete(:post_id)
          params.delete(:before_id_entity)
          params.delete(:since_id_entity)
          params
        end
      end

      class GetVersions < Middleware
        def action(env)
          return env unless env.params.post_id
          if authorize_env?(env, :read_posts)
            env.response = Model::PostVersion.fetch_all(env.params, env.current_auth)
          else
            env.response = Model::PostVersion.fetch_with_permissions(env.params, env.current_auth)
          end
          env
        end
      end

      class VersionsPaginationHeader < API::PaginationHeader
        private

        def build_next_params(env)
          params = clone_params(env)
          resource = env.response.last

          params[next_id_key(env)] = resource.version
          params
        end

        def next_id_key(env)
          if env.params.order.to_s.downcase == 'asc'
            :since_version
          else
            :before_version
          end
        end

        def build_prev_params(env)
          params = clone_params(env)
          resource = env.response.first

          params[prev_id_key(env)] = resource.version
          params
        end

        def prev_id_key(env)
          if env.params.order.to_s.downcase == 'asc'
            :before_version
          else
            :since_version
          end
        end

        def clone_params(env)
          params = super
          params.delete(:post_id)
          params.delete(:before_version)
          params.delete(:since_version)
          params
        end
      end

      class VersionsCountHeader < API::CountHeader
        def get_count(env)
          GetVersions.new(@app).call(env)
        end
      end

      class CreatePost < Middleware
        def action(env)
          authorize_post!(env)
          set_app_details(env.params.data)
          set_publicity(env.params.data)
          parse_times(env.params.data)
          data = env.params[:data].slice(*whitelisted_attributes(env))
          post = if env.params.data.id
            data.public_id = env.params.data.id
            begin
              Model::Post.create(data, :dont_notify_mentions => true)
            rescue Sequel::DatabaseError # hack to ignore duplicate posts
              Model::Post.first(:user_id => Model::User.current.id, :public_id => data.public_id)
            end
          else
            Model::Post.create(data)
          end
          post.assign_permissions(env.params.data.permissions) if post.original
          env['response'] = post
          if env.current_auth.kind_of?(Model::Follower) && auth_is_publisher?(env.current_auth, post)
            TriggerUpdates.new(@app).call(env)
          else
            env
          end
        end

        private

        def authorize_post!(env)
          post = env.params.data
          if auth_is_publisher?(env.current_auth, post)
            post.following_id = env.current_auth.id if env.current_auth.kind_of?(Model::Following)
            post.original = false
            env.authorized_scopes << :write_posts
          elsif anonymous_publisher?(env.current_auth, post) && post != env['tent.entity']
            raise Unauthorized if post.entity == env['tent.entity']
            env.authorized_scopes << :write_posts
            post.original = false
          elsif env.authorized_scopes.include?(:import_posts)
            env.authorized_scopes << :write_posts
            post.entity ||= env['tent.entity']
            post.app ||= env.current_auth.app
            post.original = post.entity == env['tent.entity']
            if post.following_id && following = Model::Following.first(:user_id => Model::User.current.id, :public_id => post.following_id)
              post.following_id = following.id
            end
          elsif env.current_auth.respond_to?(:app)
            post.entity = env['tent.entity']
            post.app = env.current_auth.app
            post.original = true
            post.following_id = nil
            post.id = nil
          end
          authorize_env!(env, :write_posts)
        end

        def whitelisted_attributes(env)
          attrs = Model::Post.write_attributes
          attrs += [:app_id] if env.current_auth.respond_to?(:app)
          attrs += [:received_at] if env.authorized_scopes.include?(:import_posts)
          attrs
        end

        def auth_is_publisher?(auth, post)
          auth.respond_to?(:entity) && auth.entity == post.entity
        end

        def anonymous_publisher?(auth, post)
          !auth && post.entity && !Model::Following.where(:user_id => Model::User.current.id, :entity => post.entity).any?
        end

        def set_app_details(post)
          if app = post.delete('app')
            post.app_url = app.url
            post.app_name = app.name
            post.app_id = app.id if app.id
          end
        end

        def set_publicity(post)
          post.public = post.permissions.public if post.permissions
        end

        def parse_times(post)
          post.published_at = Time.at(post.published_at.to_i) if post.published_at
          post.received_at = Time.at(post.received_at.to_i) if post.received_at
        end
      end

      class Update < Middleware
        def action(env)
          authorize_env!(env, :write_posts)
          if post = TentD::Model::Post.first(:id => env.params.post_id)

            unless env.current_auth.post_types.include?('all')
              raise NotFound unless env.current_auth.post_types.any? { |t| TentType.new(t).base == post.type_base }
            end

            if env.params.data.has_key?(:version) && env.params.data.keys.length == 1
              # revert to post version

              version = post.versions_dataset.first(:version => env.params.data.version)
              return env unless version # 404

              latest_version = post.latest_version(:fields => [:id])

              post.update(version.attributes.slice(*Model::Post.write_attributes))
              latest_version = post.latest_version(:fields => [:id])

              latest_version.db[:post_versions_mentions].with_sql("INSERT INTO post_versions_mentions (mention_id, post_version_id) SELECT mentions.mention_id, ? AS post_version_id FROM post_versions_mentions AS mentions WHERE mentions.post_version_id = ?", latest_version.id, version.id).insert

              latest_version.db[:post_versions_attachments].with_sql("INSERT INTO post_versions_attachments (post_attachment_id, post_version_id) SELECT attachments.post_attachment_id, ? AS post_version_id FROM post_versions_attachments AS attachments WHERE attachments.post_version_id = ?", latest_version.id, version.id).insert

              env.response = post
            else
              # update post

              version = post.latest_version(:fields => [:id])
              post.update(env.params.data.slice(:content, :licenses, :mentions, :views))

              if env.params.attachments.kind_of?(Array)
                Model::PostAttachment.db[:post_versions_attachments].with_sql("INSERT INTO post_versions_attachments (post_attachment_id, post_version_id) SELECT post_attachments.id AS post_attachment_id, ? AS post_version_id FROM post_attachments WHERE post_id = ?", version.id, post.id).insert
                Model::PostAttachment.where(:post_id => post.id).update(:post_id => nil)
              end

              env.response = post
            end
          end
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          authorize_env!(env, :write_posts)
          post = env.delete(:response)
          raise NotFound unless post.kind_of?(TentD::Model::Post) || post.kind_of?(TentD::Model::PostVersion)
          raise NotFound unless post.original

          if post.kind_of?(TentD::Model::PostVersion) && TentD::Model::PostVersion.where(:post_id => post.post_id).count == 1
            post = post.post
          end

          if post.destroy
            env.response = ''
            env.notify_deleted_post = post if post.kind_of?(TentD::Model::Post)
          end
          env
        end
      end

      class CreateAttachments < Middleware
        def action(env)
          return env unless env.params.attachments.kind_of?(Array) && env.response
          post = env.response
          version = post.latest_version(:fields => [:id])
          env.params.attachments.each do |attachment|
            attachment.tempfile.binmode
            a = Model::PostAttachment.create(
              :post => post,
              :type => attachment.type,
              :category => attachment.name, :name => attachment.filename,
              :data => Base64.strict_encode64(attachment.tempfile.read),
              :size => attachment.tempfile.size
            )

            a.db[:post_versions_attachments].insert(
              :post_attachment_id => a.id,
              :post_version_id => version.id
            )
          end
          env.response.reload
          env
        end
      end

      class CreatePlaceholderAttachments < Middleware
        def action(env)
          return env unless env.params.data.attachments.kind_of?(Array) && env.response && !env.params.attachments
          post = env.response
          version = post.latest_version(:fields => [:id])
          env.params.data.attachments.each do |attachment|
            a = Model::PostAttachment.create(
              :post => post,
              :type => attachment.type,
              :category => attachment.category.to_s,
              :name => attachment.name,
              :size => attachment[:size]
            )

            a.db[:post_versions_attachments].insert(
              :post_attachment_id => a.id,
              :post_version_id => version.id
            )
          end
          env.response.reload
          env
        end
      end

      class Notify < Middleware
        def action(env)
          return env if authorize_env?(env, :write_posts) && env.params.data && env.params.data.id && env.current_auth.kind_of?(Model::AppAuthorization)
          if deleted_post = env.notify_deleted_post
            post = Model::Post.create(
              :type => Model::Post::DELETED_POST_TYPE.uri,
              :entity => env['tent.entity'],
              :original => true,
              :content => {
                'id' => deleted_post.public_id
              }
            )
            Model::Permission.copy(deleted_post, post)
            deleted_post.notify_mentions(post.id)
          else
            return env unless (post = env.response) && post.kind_of?(Model::Post)
          end
          Notifications.trigger(:type => post.type.uri, :post_id => post.id)
          env
        end
      end

      class GetAttachment < Middleware
        def action(env)
          return env unless env.response

          post = env.response
          type = env['HTTP_ACCEPT'].split(/;|,/).first if env['HTTP_ACCEPT']

          if !post.original && post.following_id
            if following = Model::Following.first(:id => post.following_id)
              client = TentClient.new(following.core_profile.servers.first, following.auth_details.merge(:skip_serialization => true, :faraday_adapter => TentD.faraday_adapter))
              res = client.post.attachment.get(post.public_id, env.params.attachment_name, type)
              headers = res.headers
              filter_proxy_response_headers(headers)
              return [res.status, headers, [res.body]]
            else
              raise NotFound
            end
          else
            attachment = env.response.attachments_dataset.select(:data).first(:type => type, :name => env.params.attachment_name)
            if attachment
              env.response = Base64.decode64(attachment.data)
              env['response.type'] = type
            else
              env.response = nil
            end
          end

          env
        end
      end

      class GetMentions < Middleware
        def action(env)
          return env unless post = env.response
          env.post = post
          env.response = post.public_mentions(env.params.slice(:before_id, :since_id, :until_id, :limit, :post_types, :return_count))
          env
        end
      end

      class MentionsCountHeader < API::CountHeader
        def get_count(env)
          env.response = env.post
          GetMentions.new(@app).call(env)
        end
      end

      class MentionsPaginationHeader < API::PaginationHeader
        private

        def build_next_params(env)
          params = clone_params(env)
          resource = env.response.last

          params.before_id = resource.mentioned_post_id
          params.before_id_entity = resource.entity
          params
        end

        def build_prev_params(env)
          params = clone_params(env)
          resource = env.response.first

          params.since_id = resource.mentioned_post_id
          params.since_id_entity = resource.entity
          params
        end

        def clone_params(env)
          params = super
          params.delete(:post_id)
          params.delete(:before_id_entity)
          params.delete(:since_id_entity)
          params
        end
      end

      class ConfirmFollowing < Middleware
        def action(env)
          if Model::Following.where(:user_id => Model::User.current.id, :public_id => env.params.following_id).any?
            [200, { 'Content-Type' => 'text/plain' }, [env.params.challenge]]
          else
            raise NotFound
          end
        end
      end

      class TriggerUpdates < Middleware
        def action(env)
          post = env.response
          if post && post.following && post.following == env.current_auth
            case post.type.base
            when 'https://tent.io/types/post/profile'
              Notifications.update_following_profile(:following_id => post.following.id)
            when 'https://tent.io/types/post/delete'
              if deleted_post = Model::Post.first(:user_id => Model::User.current.id, :public_id => post.content['id'], :following_id => env.current_auth.id)
                deleted_post.destroy
              end
            end
          elsif post && env.current_auth.kind_of?(Model::Follower) && env.current_auth.entity == post.entity
            case post.type.base
            when 'https://tent.io/types/post/profile'
              Notifications.update_follower_entity(:follower_id => env.current_auth.id)
            end
          end
          env
        end
      end

      get '/posts/count' do |b|
        b.use GetActualId
        b.use GetCount
        b.use GetFeed
      end

      head '/posts' do |b|
        b.use GetActualId
        b.use GetFeed
        b.use PaginationHeader
        b.use CountHeader
      end

      get '/posts/:post_id' do |b|
        b.use GetActualId
        b.use GetOne, :required_scope => :read_posts
      end

      head '/posts/:post_id/versions' do |b|
        b.use GetActualId
        b.use GetVersions
        b.use VersionsPaginationHeader
        b.use VersionsCountHeader
      end

      get '/posts/:post_id/versions' do |b|
        b.use GetActualId
        b.use GetVersions
        b.use VersionsPaginationHeader
      end

      head '/posts/:post_id/mentions' do |b|
        b.use GetActualId
        b.use GetOne, :required_scope => :read_posts
        b.use GetMentions
        b.use MentionsPaginationHeader
        b.use MentionsCountHeader
      end

      get '/posts/:post_id/mentions' do |b|
        b.use GetActualId
        b.use GetOne, :required_scope => :read_posts
        b.use GetMentions
        b.use MentionsPaginationHeader
      end

      get '/posts/:post_id_entity/:post_id' do |b|
        b.use GetActualId
        b.use GetOne, :required_scope => :read_posts
      end

      get '/posts/:post_id/attachments/:attachment_name' do |b|
        b.use GetActualId
        b.use GetOne, :required_scope => :read_posts
        b.use GetAttachment
      end

      get '/posts/:post_id_entity/:post_id/attachments/:attachment_name' do |b|
        b.use GetActualId
        b.use GetOne, :required_scope => :read_posts
        b.use GetAttachment
      end

      get '/posts' do |b|
        b.use GetActualId
        b.use GetFeed
        b.use PaginationHeader
      end

      post '/posts' do |b|
        b.use CreatePost
        b.use CreateAttachments
        b.use CreatePlaceholderAttachments
        b.use Notify
      end

      post '/notifications/:following_id' do |b|
        b.use CreatePost
        b.use CreateAttachments
        b.use CreatePlaceholderAttachments
        b.use Notify
        b.use TriggerUpdates
      end

      get '/notifications/:following_id' do |b|
        b.use ConfirmFollowing
      end

      put '/posts/:post_id' do |b|
        b.use GetActualId
        b.use Update
        b.use CreateAttachments
        b.use Notify
      end

      delete '/posts/:post_id' do |b|
        b.use GetActualId
        b.use GetOne, :required_scope => :write_posts
        b.use Destroy
        b.use Notify
      end
    end
  end
end
