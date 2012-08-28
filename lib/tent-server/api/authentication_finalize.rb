module TentServer
  class API
    class AuthenticationFinalize < Middleware
      def action(env, params, request)
        return env unless env['hmac']
        env['current_server'] = env['potential_server'] if env['potential_server']
        env['current_app'] = env['potential_app'] if env['potential_app']
        env['current_user'] = env['potential_user'] if env['potential_user']
        instance = env['current_server'] || env['current_app'] || env['current_user']
        instance.update(:mac_timestamp_delta => Time.now.to_i - env['hmac']['ts'].to_i) unless instance.mac_timestamp_delta
        env
      end
    end
  end
end
