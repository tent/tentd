module TentD
  class API

    class AuthorizeGetEntity < Middleware
      def action(env)
        entity = env['params'][:entity]
        unless entity == env['current_user'].entity
          auth_candidate = Authorizer.new(env).auth_candidate
          halt!(404, "Not Found") unless auth_candidate && auth_candidate.read_entity?(entity)
        end

        env
      end
    end

  end
end
