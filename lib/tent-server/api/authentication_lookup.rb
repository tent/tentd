module TentServer
  class API
    class AuthenticationLookup < Middleware
      def action(env, params, request)
        return env unless env['Authorization']
        env['hmac'] = Hash[env['Authorization'].scan(/([a-z]+)="([^"]+)"/i)]
        case env['hmac']['id'].to_s[0,1]
        when 's'
          env['potential_server'] = TentServer::Model::Follower.first(:mac_key_id => env['hmac']['id'])
          env['hmac.key'] = env['potential_server'].mac_key
          env['hmac.algorithm'] = env['potential_server'].mac_algorithm
        when 'a'
          env['potential_app'] = TentServer::Model::App.first(:mac_key_id => env['hmac']['id'])
          env['hmac.key'] = env['potential_app'].mac_key
          env['hmac.algorithm'] = env['potential_app'].mac_algorithm
        when 'u'
          env['potential_user'] = TentServer::Model::AppAuthorization.first(:mac_key_id => env['hmac']['id'])
          env['hmac.key'] = env['potential_user'].mac_key
          env['hmac.algorithm'] = env['potential_user'].mac_algorithm
        end
        env
      end
    end
  end
end
