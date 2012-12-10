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

      class GetOne < Middleware
        def action(env)
          env.response = Model::ProfileInfo.get_profile_type(env.params.delete(:type_uri), env.params, env.authorized_scopes, env.current_auth)
          env
        end
      end

      class Update < Middleware
        def action(env)
          data = env.params.data
          type = URI.unescape(env.params.type_uri)
          raise Unauthorized unless ['all', type].find { |t| env.current_auth.profile_info_types.include?(t) }
          env.updated_info = Model::ProfileInfo.update_profile(type, data)
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          type = TentType.new(env.params.type_uri)
          if env.params.has_key?(:version) && Model::ProfileInfoVersion.where(:type_base => type.base, :type_version => type.version.to_s).count > 1
            if (info_version = Model::ProfileInfoVersion.where(:version => env.params.version.to_i, :type_base => type.base, :type_version => type.version.to_s).first) && info_version.destroy
              env.response = ''
            end
          else
            if (info = Model::ProfileInfo.where(:type_base => type.base, :type_version => type.version.to_s).first) && (!env.params.has_key?(:version) || info.latest_version(:fields => [:version]).version == env.params.version.to_i) && info.destroy
              env.response = ''
            end
          end
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

      put '/profile/:type_uri' do |b|
        b.use AuthorizeWrite
        b.use Update
        b.use Get
        b.use Notify
      end

      get '/profile/:type_uri' do |b|
        b.use GetOne
      end

      delete '/profile/:type_uri' do |b|
        b.use AuthorizeWrite
        b.use Destroy
      end
    end
  end
end
