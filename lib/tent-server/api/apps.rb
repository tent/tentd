module TentServer
  class API
    class Apps
      include Router

      class Create < Middleware
        def action(env)
          env.response = TentServer::Model::App.create_from_params(env.params.data)
          env
        end
      end

      post '/apps' do |b|
        b.use Create
      end
    end
  end
end
