module TentServer
  class API
    module Authorizable
      class Error < StandardError
      end

      class Unauthorized < Error
      end

      def authorize_env!(env, scope)
        unless authorize_env?(env, scope)
          raise Unauthorized
        end
      end

      def authorize_env?(env, scope)
        env.authorized_scopes.to_a.include?(scope)
      end
    end
  end
end
