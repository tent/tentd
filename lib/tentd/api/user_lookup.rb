module TentD
  class API

    class UserLookup < Middleware
      EntityNotSetError = Class.new(StandardError)

      def action(env)
        unless env['current_user']
          raise EntityNotSetError.new("You need to set ENV['TENT_ENTITY']!") unless ENV['TENT_ENTITY']
          env['current_user'] = Model::User.first_or_create(ENV['TENT_ENTITY'])
        end
        env
      end
    end

  end
end
