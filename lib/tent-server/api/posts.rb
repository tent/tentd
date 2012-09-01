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
          posts = Model::Post.all(:public_uid => id_mapping.keys, :fields => [:id, :public_uid])
          posts.each do |post|
            key = id_mapping[post.public_uid]
            env.params[key] = post.id
          end
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if authorize_env?(env, :read_posts)
            post = Model::Post.get(env.params.post_id)
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
            env['response'] = Model::Post.fetch_all(env.params)
          else
            env['response'] = Model::Post.fetch_with_permissions(env.params, env.current_auth)
          end
          env
        end
      end

      class Create < Middleware
        def action(env)
          authorize_env!(env, :write_posts)
          post_attributes = env.params[:data]
          post = Model::Post.create!(post_attributes)
          env['response'] = post
          env
        end
      end

      get '/posts/:post_id' do |b|
        b.use GetActualId
        b.use GetOne
      end

      get '/posts' do |b|
        b.use GetActualId
        b.use GetFeed
      end

      post '/posts' do |b|
        b.use Create
      end
    end
  end
end
