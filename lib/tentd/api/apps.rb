module TentD
  class API
    class Apps
      include Router

      class GetActualId < Middleware
        def action(env)
          if env.params.app_id
            if app = Model::App.first(:user_id => Model::User.current.id, :public_id => env.params.app_id)
              env.params.app_id = app.id
            else
              env.params.app_id = nil
            end
          end

          if env.params.auth_id
            if app_auth = Model::AppAuthorization.first(:public_id => env.params.auth_id)
              env.params.auth_id = app_auth.id
            else
              env.params.auth_id = nil
            end
          end

          env
        end
      end

      class AuthorizeReadOne < Middleware
        def action(env)
          authorize_env!(env, :read_apps) unless env.params.app_id && env.current_auth &&
                                                 env.current_auth.kind_of?(Model::App) &&
                                                 env.current_auth.id == env.params.app_id
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
          if app = Model::App.first(:id => env.params.app_id)
            env.response = app
          end
          env
        end
      end

      class GetAll < Middleware
        def action(env)
          env.response = Model::App.where(:user_id => Model::User.current.id).all
          env
        end
      end

      class Create < Middleware
        def action(env)
          if authorize_env?(env, :write_apps) && authorize_env?(env, :write_secrets)
            app_fields = Model::App.public_attributes + [:mac_key_id, :mac_key, :mac_algorithm, :public_id]
            data = env.params.data
            data.public_id = data.delete(:id) if data.id

            data = app_fields.inject({}) { |memo, (k,v)|
              memo[k] = data[k] if data.has_key?(k)
              memo
            }
            env.response = Model::App.create(data)
          else
            env.response = Model::App.create_from_params(env.params.data || {})
          end
          env.authorized_scopes << :read_secrets
          env
        end
      end

      class CreateAuthorization < Middleware
        def action(env)
          unless authorize_env?(env, :write_apps) && authorize_env?(env, :write_secrets)
            if env.params.data && env.params.data.code
              return AuthorizationTokenExchange.new(@app).call(env)
            else
              authorize_env!(env, :write_apps)
              authorize_env!(env, :write_secrets)
            end
          end

          if app = Model::App.first(:id => env.params.app_id)
            env.authorized_scopes << :authorization_token

            data = env.params.data
            data.post_types = data.post_types.to_a.map { |url| URI.decode(url) }
            data.profile_info_types = data.profile_info_types.to_a.map { |url| URI.decode(url) }
            data.public_id = data.id if data.id
            attributes = data.slice(
              :post_types,
              :profile_info_types,
              :scopes,
              :mac_key_id,
              :mac_key,
              :mac_algorithm,
              :notification_url,
              :follow_url,
              :public_id
            ).merge(
              :app_id => env.params.app_id
            )
            authorization = Model::AppAuthorization.create_from_params(attributes)
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

      class UpdateAppAuthorization < Middleware
        def action(env)
          authorize_env!(env, :write_apps)
          if (auth = TentD::Model::AppAuthorization.first(:app_id => env.params.app_id, :id => env.params.auth_id)) &&
              auth.update_from_params(env.params.data)
            env.response = auth
          end
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (app = Model::App.first(:id => env.params.app_id)) && app.destroy
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
        b.use AuthorizeWriteOne
        b.use CreateAuthorization
      end

      put '/apps/:app_id/authorizations/:auth_id' do |b|
        b.use GetActualId
        b.use UpdateAppAuthorization
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
