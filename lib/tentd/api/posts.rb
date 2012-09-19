module TentD
  class API
    class Posts
      include Router

      class GetActualId < Middleware
        def action(env)
          id_mapping = [:post_id, :since_id, :before_id].select { |key| env.params.has_key?(key) }.inject({}) { |memo, key|
            memo[env.params[key]] = key
            env.params[key] = nil
            memo
          }
          posts = Model::Post.all(:public_id => id_mapping.keys, :fields => [:id, :public_id])
          posts.each do |post|
            key = id_mapping[post.public_id]
            env.params[key] = post.id
          end
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if authorize_env?(env, :read_posts)
            conditions = { :id => env.params.post_id }
            unless env.current_auth.post_types.include?('all')
              conditions[:type_base] = env.current_auth.post_types.map { |t| TentType.new(t).base }
            end

            if env.params.version
              conditions[:fields] = [:id]
            end

            post = Model::Post.first(conditions)
          else
            post = Model::Post.find_with_permissions(env.params.post_id, env.current_auth)
          end
          if post
            if env.params.version
              if post_version = post.versions.first(:version => env.params.version.to_i)
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
          if authorize_env?(env, :read_posts)
            conditions = {}
            non_public_conditions = {}
            conditions[:id.gt] = env.params.since_id if env.params.since_id
            conditions[:id.lt] = env.params.before_id if env.params.before_id
            conditions[:published_at.gt] = Time.at(env.params.since_time.to_i) if env.params.since_time
            conditions[:published_at.lt] = Time.at(env.params.before_time.to_i) if env.params.before_time
            conditions[:entity] = env.params.entity if env.params.entity
            if env.params.mentioned_post && env.params.mentioned_entity
              conditions[:mentions] = {
                :mentioned_post_id => env.params.mentioned_post,
                :entity => env.params.mentioned_entity
              }
            end
            if env.params.post_types
              types = env.params.post_types.split(',').map { |t| TentType.new(URI.unescape(t)) }

              non_public_conditions[:type_base] = types.select do |type|
                env.current_auth.post_types.include?('all') ||
                env.current_auth.post_types.include?(type.uri)
              end.map(&:base)

              conditions[:type_base] = types.map(&:base)

            elsif !env.current_auth.post_types.include?('all')
              non_public_conditions[:type_base] = env.current_auth.post_types.map { |t| TentType.new(t).base }
            end
            if env.params.limit
              conditions[:limit] = [env.params.limit.to_i, TentD::API::MAX_PER_PAGE].min
            else
              conditions[:limit] = TentD::API::PER_PAGE
            end
            
            if env.params.return_count
              env.response = Model::Post.count(conditions.merge(non_public_conditions))
              env.response += Model::Post.count(conditions.merge(:public => true))
            else
              conditions[:order] = :published_at.desc
              if conditions[:limit] == 0
                env.response = []
              else
                env.response = Model::Post.all(conditions.merge(non_public_conditions))
                env.response += Model::Post.all(conditions.merge(:public => true))
              end
            end
          else
            env.response = Model::Post.fetch_with_permissions(env.params, env.current_auth)
          end
          env
        end
      end

      class CreatePost < Middleware
        def action(env)
          authorize_post!(env)
          set_app_details(env.params.data)
          set_publicity(env.params.data)
          parse_times(env.params.data)
          data = env.params[:data].slice(*whitelisted_attributes(env))
          data.public_id = env.params.data.id if env.params.data.id
          post = Model::Post.create(data)
          assign_permissions(post, env.params.data.permissions)
          env['response'] = post
          env
        end

        private

        def authorize_post!(env)
          post = env.params.data
          if auth_is_publisher?(env.current_auth, post)
            post.known_entity = true
            env.authorized_scopes << :write_posts
          elsif anonymous_publisher?(env.current_auth, post) && post != env['tent.entity']
            post.known_entity = false
            env.authorized_scopes << :write_posts
          elsif env.authorized_scopes.include?(:import_posts)
            post.entity ||= env['tent.entity']
            post.app ||= env.current_auth.app
            post.known_entity = nil if post.known_entity.nil?
          elsif env.current_auth.respond_to?(:app)
            post.entity = env['tent.entity']
            post.app = env.current_auth.app
            post.known_entity = nil
          end
          post.original = post.entity == env['tent.entity']
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
          !auth && post.entity && !Model::Following.first(:entity => post.entity, :fields => [:id])
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

        def assign_permissions(post, permissions)
          return unless post.original && permissions
          if permissions.groups && permissions.groups.kind_of?(Array)
            permissions.groups.each do |g|
              next unless g.id
              group = Model::Group.first(:public_id => g.id, :fields => [:id])
              post.permissions.create(:group => group) if group
            end
          end

          if permissions.entities && permissions.entities.kind_of?(Hash)
            permissions.entities.each do |entity,visible|
              next unless visible
              followers = Model::Follower.all(:entity => entity, :fields => [:id])
              followers.each do |follower|
                post.permissions.create(:follower_access => follower)
              end
              followings = Model::Following.all(:entity => entity, :fields => [:id])
              followings.each do |following|
                post.permissions.create(:following => following)
              end
            end
          end
        end
      end

      class Update < Middleware
        def action(env)
          authorize_env!(env, :write_posts)
          if post = TentD::Model::Post.first(:id => env.params.post_id)
            version = post.latest_version(:fields => [:id])
            post.update(env.params.data.slice(:content, :licenses, :mentions, :views))

            if env.params.attachments.kind_of?(Array)
              Model::PostAttachment.all(:post_id => post.id).update(:post_id => nil, :post_version_id => version.id)
            end

            env.response = post
          end
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          authorize_env!(env, :write_posts)
          if (post = TentD::Model::Post.first(:id => env.params.post_id)) && post.destroy
            raise Unauthorized unless post.original
            env.response = ''
            env.notify_deleted_post = post
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
            Model::PostAttachment.create(:post => post,
                                         :post_version => version,
                                         :type => attachment.type,
                                         :category => attachment.name, :name => attachment.filename,
                                         :data => Base64.encode64(attachment.tempfile.read), :size => attachment.tempfile.size)
          end
          env.response.reload
          env
        end
      end

      class Notify < Middleware
        def action(env)
          if deleted_post = env.notify_deleted_post
            post = Model::Post.create(
              :type => 'https://tent.io/types/post/delete/v0.1.0',
              :entity => env['tent.entity'],
              :content => {
                :id => deleted_post.public_id
              }
            )
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
          type = env['HTTP_ACCEPT'].split(/;|,/).first if env['HTTP_ACCEPT']
          attachment = env.response.attachments.first(:type => type, :name => env.params.attachment_name, :fields => [:data])
          if attachment
            env.response = Base64.decode64(attachment.data)
            env['response.type'] = type
          else
            env.response = nil
          end
          env
        end
      end

      class ConfirmFollowing < Middleware
        def action(env)
          if Model::Following.first(:public_id => env.params.following_id)
            [200, { 'Content-Type' => 'text/plain' }, [env.params.challenge]]
          else
            [404, {}, []]
          end
        end
      end

      get '/posts/count' do |b|
        b.use GetCount
        b.use GetFeed
      end

      get '/posts/:post_id' do |b|
        b.use GetActualId
        b.use GetOne
      end

      get '/posts/:post_id/attachments/:attachment_name' do |b|
        b.use GetActualId
        b.use GetOne
        b.use GetAttachment
      end

      get '/posts' do |b|
        b.use GetActualId
        b.use GetFeed
      end

      post '/posts' do |b|
        b.use CreatePost
        b.use CreateAttachments
        b.use Notify
      end

      post '/notifications/:following_id' do |b|
        b.use CreatePost
        b.use CreateAttachments
        b.use Notify
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
        b.use Destroy
        b.use Notify
      end
    end
  end
end
