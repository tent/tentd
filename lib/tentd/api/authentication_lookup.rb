module TentD
  class API
    class AuthenticationLookup < Middleware
      def action(env)
        return env unless env['HTTP_AUTHORIZATION']
        env['hmac'] = Hash[env['HTTP_AUTHORIZATION'].scan(/([a-z]+)="([^"]+)"/i)]
        case env['hmac']['id'].to_s[0,1]
        when 's'
          env.potential_auth = TentD::Model::Follower.first(:mac_key_id => env['hmac']['id'])
        when 'a'
          env.potential_auth = TentD::Model::App.first(:mac_key_id => env['hmac']['id'])
        when 'u'
          env.potential_auth = TentD::Model::AppAuthorization.first(:mac_key_id => env['hmac']['id'])
        end
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
