module TentServer
  class API
    class Posts
      include Router

      class Get < Middleware
        def action(env, params, request)
          if post = ::TentServer::Model::Post.get(params[:post_id])
            env['response'] = post
          else
            env['response.status'] = 404
          end
          env
        end
      end

      get '/posts/:post_id' do |b|
        b.use Get
      end
    end
  end
end
