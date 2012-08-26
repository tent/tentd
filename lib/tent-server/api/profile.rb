module TentServer
  class API
    class Profile
      include Router

      class Get < Middleware
        def action(env, params, request)
          env['response'] = ::TentServer::Model::ProfileInfo.build_for_entity(env['tent.entity'])
          env
        end
      end

      get '/profile' do |b|
        b.use Get
      end
    end
  end
end
