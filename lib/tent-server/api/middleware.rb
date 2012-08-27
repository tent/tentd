module TentServer
  class API
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        response = action(env, env['params'], env['request'])
        response.kind_of?(Hash) ? @app.call(response) : response
      end
    end
  end
end
