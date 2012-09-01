module TentServer
  class API
    module Authorizable
      class Error < StandardError
      end

      class Unauthorized < Error
      end

      def authorize_env!(env, scope)
        puts [env, scope].inspect
        unless env.authorized_scopes.to_a.include?(scope)
          raise Unauthorized
        end
      end
    end
  end
end
