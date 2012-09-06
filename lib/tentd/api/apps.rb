module TentD
  class API
    class Apps
      include Router

      class GetActualId < Middleware
        def action(env)
          if env.params.app_id
            if app = Model::App.first(:public_id => env.params.app_id)
              env.params.app_id = app.id
            else
              env.params.app_id = nil
            end
          end
          env
        end
      end

      class AuthorizeReadOne < Middleware
        def action(env)
          if env.params.app_id && env.current_auth && ((env.current_auth.kind_of?(Model::AppAuthorization) &&
                 env.current_auth.app_id == env.params.app_id) || (env.current_auth.kind_of?(Model::App) && env.current_auth.id == env.params.app_id))
            (env.authorized_scopes ||= []) << :read_secrets if env.params.read_secrets.to_s == 'true'
          else
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
          authorize_env!(env, :write_apps) unless env.params.app_id && env.current_auth &&
                                                  env.current_auth.kind_of?(Model::App) &&
                                                  env.current_auth.id == env.params.app_id
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if app = Model::App.get(env.params.app_id)
            env.response = app
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
          env.authorized_scopes << :self
          env.response = Model::App.create_from_params(env.params.data)
          env
        end
      end

      class CreateAuthorization < Middleware
        def action(env)
          unless authorize_env?(env, :write_apps)
            if env.params.data.code
              return AuthorizationTokenExchange.new(@app).call(env)
            else
              authorize_env!(env, :write_apps)
            end
          end

          if app = Model::App.get(env.params.app_id)
            env.authorized_scopes << :authorization_token
            authorization = app.authorizations.create(env.params.data.merge({
              :post_types => env.params.data.post_types.to_a.map { |url| URI.decode(url) },
              :profile_info_types => env.params.data.profile_info_types.to_a.map { |url| URI.decode(url) },
            }))
            env.response = authorization
          end
          env
        end
      end

      class AuthorizationTokenExchange < Middleware
        def action(env)
          if authorization = Model::AppAuthorization.first(:app_id => env.params.app_id, :token_code => env.params.data.code)
            env.response = authorization.token_exchange!
          else
            raise Unauthorized
          end
          env
        end
      end

      class Update < Middleware
        def action(env)
          if app = Model::App.update_from_params(env.params.app_id, env.params.data)
            env.response = app
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

      class DestroyAppAuthorization < Middleware
        def action(env)
          authorize_env!(env, :write_apps)
          if (auth = TentD::Model::AppAuthorization.first(:app_id => env.params.app_id, :id => env.params.auth_id)) &&
            auth.destroy
            env.response = ''
          end
          env
        end
      end

      get '/apps/:app_id' do |b|
        b.use GetActualId
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

      post '/apps/:app_id/authorizations' do |b|
        b.use GetActualId
        b.use CreateAuthorization
      end

      delete '/apps/:app_id/authorizations/:auth_id' do |b|
        b.use GetActualId
        b.use DestroyAppAuthorization
      end

      put '/apps/:app_id' do |b|
        b.use GetActualId
        b.use AuthorizeWriteOne
        b.use Update
      end

      delete '/apps/:app_id' do |b|
        b.use GetActualId
        b.use AuthorizeWriteOne
        b.use Destroy
      end
    end
  end
end
