module TentD
  class API
    class Profile
      include Router

      class AuthorizeWrite < Middleware
        def action(env)
          authorize_env!(env, :write_profile)
          env
        end
      end

      class Get < Middleware
        def action(env)
          env.response = Model::ProfileInfo.get_profile(env.authorized_scopes, env.current_auth)
          env
        end
      end

      class Update < Middleware
        def action(env)
          data = env.params.data
          type = URI.unescape(env.params.type_url)
          raise Unauthorized unless ['all', type].find { |t| env.current_auth.profile_info_types.include?(t) }
          env.updated_info = Model::ProfileInfo.update_profile(type, data)
          env
        end
      end

      class Notify < Middleware
        def action(env)
          return env unless env.updated_info
          Array(env.updated_info).each do |info|
            Notifications.profile_info_update(
              :profile_info_id => info.id,
              :entity_changed => info.entity_changed,
              :old_entity => info.old_entity
            )
          end
          env
        end
      end

      get '/profile' do |b|
        b.use Get
      end

      put '/profile/:type_url' do |b|
        b.use AuthorizeWrite
        b.use Update
        b.use Get
        b.use Notify
      end
    end
  end
end
