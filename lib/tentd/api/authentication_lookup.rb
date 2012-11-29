module TentD
  class API
    class AuthenticationLookup < Middleware
      def action(env)
        return env unless env['HTTP_AUTHORIZATION']
        env.hmac = Hash[env['HTTP_AUTHORIZATION'].scan(/([a-z]+)="([^"]+)"/i)]
        mac_key_id = env.hmac.id
        env.potential_auth = case mac_key_id.to_s[0,1]
        when 's'
          TentD::Model::Follower.first(:user_id => TentD::Model::User.current.id, :mac_key_id => mac_key_id)
        when 'a'
          TentD::Model::App.first(:user_id => TentD::Model::User.current.id, :mac_key_id => mac_key_id)
        when 'u'
          TentD::Model::AppAuthorization.qualify.join(
            :apps,
            :app_authorizations__app_id => :apps__id
          ).where(
            :apps__user_id => TentD::Model::User.current.id,
            :app_authorizations__mac_key_id => mac_key_id,
            :apps__deleted_at => nil
          ).first
        end
        env.potential_auth = Model::Following.first(:user_id => TentD::Model::User.current.id, :mac_key_id => mac_key_id) unless env.potential_auth
        if env.potential_auth
          env.hmac.secret = env.potential_auth.mac_key
          env.hmac.algorithm = env.potential_auth.mac_algorithm
        elsif mac_key_id
          return [401, {'WWW-Authenticate' => 'MAC', 'Content-Type' => MEDIA_TYPE}, [{ 'error' => 'Invalid MAC Key ID' }.to_json]]
        else
          env.hmac = nil
        end
        env
      end
    end
  end
end
