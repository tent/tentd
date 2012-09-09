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
            post = Model::Post.first(conditions)
          else
            post = Model::Post.find_with_permissions(env.params.post_id, env.current_auth)
          end
          if post
            env['response'] = post
          end
          env
        end
      end

      class GetFeed < Middleware
        def action(env)
          if authorize_env?(env, :read_posts)
            conditions = {}
            conditions[:id.gt] = env.params.since_id if env.params.since_id
            conditions[:id.lt] = env.params.before_id if env.params.before_id
            conditions[:published_at.gt] = Time.at(env.params.since_time.to_i) if env.params.since_time
            conditions[:published_at.lt] = Time.at(env.params.before_time.to_i) if env.params.before_time
            if env.params.post_types
              conditions[:type_base] = env.params.post_types.split(',').map do |type|
                URI.unescape(type)
              end.select do |type|
                env.current_auth.post_types.include?('all') ||
                env.current_auth.post_types.include?(type)
              end
            elsif !env.current_auth.post_types.include?('all')
              conditions[:type_base] = env.current_auth.post_types.map { |t| TentType.new(t).base }
            end
            if env.params.limit
              conditions[:limit] = [env.params.limit.to_i, TentD::API::MAX_PER_PAGE].min
            else
              conditions[:limit] = TentD::API::PER_PAGE
            end
            if conditions[:limit] == 0
              env.response = []
            else
              env.response = Model::Post.all(conditions)
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
              post.permissions << Model::Permission.new(:group => group) if group
            end
          end

          if permissions.entities && permissions.entities.kind_of?(Hash)
            permissions.entities.each do |entity,visible|
              next unless visible
              followers = Model::Follower.all(:entity => entity, :fields => [:id])
              followers.each do |follower|
                post.permissions << Model::Permission.new(:follower => follower)
              end
            end
          end
        end
      end

      class Destroy < Middleware
        def action(env)
          authorize_env!(env, :write_posts)
          if (post = TentD::Model::Post.get(env.params.post_id)) && post.destroy
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
          env.params.attachments.each do |attachment|
            Model::PostAttachment.create(:post => env.response, :type => attachment.type,
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
          Notifications::TRIGGER_QUEUE << { :type => post.type, :post_id => post.id }
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

      delete '/posts/:post_id' do |b|
        b.use GetActualId
        b.use Destroy
        b.use Notify
      end
    end
  end
end
