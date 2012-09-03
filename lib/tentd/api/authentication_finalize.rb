module TentD
  class API
    class AuthenticationFinalize < Middleware
      def action(env)
        return env unless env.hmac? && env.hmac.verified
        env.current_auth = env.potential_auth
        env.current_auth.update(:mac_timestamp_delta => Time.now.to_i - env.hmac.ts.to_i) unless env.current_auth.mac_timestamp_delta
        env
      end
    end
  end
end
