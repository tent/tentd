module TentD
  class API
    class Authorization < Middleware
      def action(env)
        env.authorized_scopes = []
        if env.current_auth.kind_of?(Model::AppAuthorization)
          env.authorized_scopes = env.current_auth.scopes.to_a.map(&:to_sym)
          env.authorized_scopes.delete(:read_secrets) unless env.params && env.params.secrets.to_s == 'true'
        end
        env
      end
    end
  end
end
