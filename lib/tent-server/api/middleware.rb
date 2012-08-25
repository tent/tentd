module TentServer
  class API
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call action(env, env['params'], env['request'])
      end
    end
  end
end
