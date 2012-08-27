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

      class Update < Middleware
        def action(env, params, request)
          data = JSON.parse(env['rack.input'].read)
          ::TentServer::Model::ProfileInfo.update_for_entity(env['tent.entity'], data)
          env['response'] = ::TentServer::Model::ProfileInfo.build_for_entity(env['tent.entity'])
          env
        end
      end

      get '/profile' do |b|
        b.use Get
      end

      put '/profile' do |b|
        b.use Update
      end
    end
  end
end
