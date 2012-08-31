module TentServer
  class API
    class Posts
      include Router

      class GetActualId < Middleware
        def action(env)
          if env.params.post_id
            if post = Model::Post.first(:public_uid => env.params.post_id, :fields => [:id])
              env.params.post_id = post.id
            else
              env.params.post_id = nil
            end
          end
          if env.params.since_id
            if post = Model::Post.first(:public_uid => env.params.since_id, :fields => [:id])
              env.params.since_id = post.id
            else
              env.params.since_id = nil
            end
          end
          if env.params.before_id
            if post = Model::Post.first(:public_uid => env.params.before_id, :fields => [:id])
              env.params.before_id = post.id
            else
              env.params.before_id = nil
            end
          end
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          post = Model::Post.find_with_permissions(env.params.post_id, env.current_auth)
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
