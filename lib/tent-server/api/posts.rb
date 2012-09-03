module TentServer
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
              conditions[:type] = env.current_auth.post_types
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
              conditions[:type] = env.params.post_types.split(',').map do |type|
                URI.unescape(type)
              end.select do |type|
                env.current_auth.post_types.include?('all') ||
                env.current_auth.post_types.include?(type)
              end
            elsif !env.current_auth.post_types.include?('all')
              conditions[:type] = env.current_auth.post_types
            end
            if env.params.limit
              conditions[:limit] = [env.params.limit.to_i, TentServer::API::MAX_PER_PAGE].min
            else
              conditions[:limit] = TentServer::API::PER_PAGE
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
          authorize_env!(env, :write_posts)
          post_attributes = env.params[:data]
          post = Model::Post.create!(post_attributes)
          env['response'] = post
          env
        end
      end

      class CreateAttachments < Middleware
        def action(env)
          return env unless env.params.attachments.kind_of?(Array)
          env.params.attachments.each do |attachment|
            Model::PostAttachment.create(:post => env.response, :type => attachment.type,
                                         :category => attachment.name, :name => attachment.filename,
                                         :data => attachment.tempfile.read, :size => attachment.tempfile.size)
          end
          env.response.reload
          env
        end
      end

      class GetAttachment < Middleware
        def action(env)
          return env unless env.response
          type = env['HTTP_ACCEPT'].split(/;|,/).first if env['HTTP_ACCEPT']
          attachment = env.response.attachments.first(:type => type, :name => env.params.attachment_name, :fields => [:data])
          if attachment
            env.response = attachment.data
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
      end
    end
  end
end
