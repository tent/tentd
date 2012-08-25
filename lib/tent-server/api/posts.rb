module TentServer
  class API
    class Posts
      include Router

      class Get < Middleware
        def action(env, params, request)
          env['response'] = ::TentServer::Model::Post.get(params[:post_id])
          env
        end
      end

      get '/posts/:post_id' do |b|
        b.use Get
      end
    end
  end
end
