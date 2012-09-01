module TentServer
  class API
    class Apps
      include Router

      class AuthorizeReadOne < Middleware
        def action(env)
          unless env.params.app_id && env.current_auth && env.current_auth.kind_of?(Model::AppAuthorization) &&
                 env.current_auth.app_id == env.params.app_id
            authorize_env!(env, :read_apps)
          end
          env
        end
      end

      class AuthorizeReadAll < Middleware
        def action(env)
          authorize_env!(env, :read_apps)
          env
        end
      end

      class AuthorizeWriteOne < Middleware
        def action(env)
          unless env.params.app_id && env.current_auth && env.current_auth.kind_of?(Model::AppAuthorization) &&
                 env.current_auth.app_id == env.params.app_id
            authorize_env!(env, :write_apps)
          end
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if app = Model::App.get(env.params.app_id)
            env.response = app.as_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id])
          end
          env
        end
      end

      class GetAll < Middleware
        def action(env)
          env.response = Model::App.all
          env
        end
      end

      class Create < Middleware
        def action(env)
          env.response = Model::App.create_from_params(env.params.data).as_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id, :mac_key, :mac_algorithm])
          env
        end
      end

      class Update < Middleware
        def action(env)
          if app = Model::App.update_from_params(env.params.app_id, env.params.data)
            env.response = app.as_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id])
          end
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (app = Model::App.get(env.params.app_id)) && app.destroy
            env.response = ''
          end
          env
        end
      end

      get '/apps/:app_id' do |b|
        b.use AuthorizeReadOne
        b.use GetOne
      end

      get '/apps' do |b|
        b.use AuthorizeReadAll
        b.use GetAll
      end

      post '/apps' do |b|
        b.use Create
      end

      put '/apps/:app_id' do |b|
        b.use AuthorizeWriteOne
        b.use Update
      end

      delete '/apps/:app_id' do |b|
        b.use AuthorizeWriteOne
        b.use Destroy
      end
    end
  end
end
