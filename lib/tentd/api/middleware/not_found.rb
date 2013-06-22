module TentD
  class API

    class NotFound < Middleware
      def action(env)
        halt!(404, "Not Found")
      end
    end

  end
end
