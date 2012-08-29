module TentServer
  class API
    class Posts
      include Router

      class GetOne < Middleware
        def action(env)
          post = Model::Post.first(:id => env.params[:post_id], :public => true)
          if env.current_auth
            post ||= Model::Post.find_with_permissions(env.params[:post_id], env.current_auth)
          end
          if post
            env['response'] = post
          end
          env
        end
      end

      class GetFeed < Middleware
        def action(env)
          env['response'] = Model::Post.fetch_with_permissions(env.params, env.current_auth)
          env
        end
      end

      class Create < Middleware
        def action(env)
          post_attributes = env.params[:data]
          post = Model::Post.create!(post_attributes)
          env['response'] = post
          env
        end
      end

      get '/posts/:post_id' do |b|
        b.use GetOne
      end

      get '/posts' do |b|
        b.use GetFeed
      end

      post '/posts' do |b|
        b.use Create
      end
    end
  end
end
