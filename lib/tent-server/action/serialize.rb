module TentServer
  module Action
    class Serialize
      def initialize(app)
        @app = app
      end

      def call(env)
        puts env['tent.post'].inspect
        env['response'] = env['tent.post'].to_json
        @app.call(env)
      end
    end
  end
end
