module TentD
  class Authorizer

    module AuthCandidate
      require 'tentd/authorizer/auth_candidate/base'
      require 'tentd/authorizer/auth_candidate/app_auth'
      require 'tentd/authorizer/auth_candidate/app'
      require 'tentd/authorizer/auth_candidate/relationship'

      def self.new(current_user, resource)
        case TentType.new(resource.type).base
        when %(https://tent.io/types/app-auth)
          AppAuth.new(current_user, resource)
        when %(https://tent.io/types/app)
          App.new(current_user, resource)
        when %(https://tent.io/types/relationship)
          Relationship.new(current_user, resource)
        else
          Base.new(current_user, resource)
        end
      end
    end

  end
end
