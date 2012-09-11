module TentD
  class API
    class UserLookup < Middleware
      def action(env)
        Model::User.current = Model::User.first_or_create
        env
      end
    end
  end
end
