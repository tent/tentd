module TentServer
  class API
    class Apps
      include Router

      class GetAll < Middleware
        def action(env)
          env.response = TentServer::Model::App.all
          env
        end
      end

      class Create < Middleware
        def action(env)
          env.response = TentServer::Model::App.create_from_params(env.params.data).as_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id, :mac_key, :mac_algorithm])
          env
        end
      end

      get '/apps' do |b|
        b.use GetAll
      end

      post '/apps' do |b|
        b.use Create
      end
    end
  end
end
