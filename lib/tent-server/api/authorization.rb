module TentServer
  class API
    class Authorization < Middleware
      def action(env)
        env.authorized_scopes = []
        if env.current_auth.kind_of?(Model::AppAuthorization)
          env.authorized_scopes = env.current_auth.scopes.map(&:to_sym)
        end
        env
      end
    end
  end
end
