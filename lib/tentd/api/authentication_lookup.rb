module TentD
  class API
    class AuthenticationLookup < Middleware
      def action(env)
        return env unless env['HTTP_AUTHORIZATION']
        env['hmac'] = Hash[env['HTTP_AUTHORIZATION'].scan(/([a-z]+)="([^"]+)"/i)]
        mac_key_id = env['hmac']['id']
        env.potential_auth = case mac_key_id.to_s[0,1]
        when 's'
          TentD::Model::Follower.first(:mac_key_id => mac_key_id)
        when 'a'
          TentD::Model::App.first(:mac_key_id => mac_key_id)
        when 'u'
          TentD::Model::User.current.apps.authorizations.first(:mac_key_id => mac_key_id)
        end
        env.potential_auth = Model::Following.first(:mac_key_id => mac_key_id) unless env.potential_auth
        if env.potential_auth
          env.hmac.secret = env.potential_auth.mac_key
          env.hmac.algorithm = env.potential_auth.mac_algorithm
        else
          env.hmac = nil
        end
        env
      end
    end
  end
end
