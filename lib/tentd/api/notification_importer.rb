module TentD
  class API

    class NotificationImporter
      def self.call(env)
        new(env).perform
      end

      attr_reader :env
      def initialize(env)
        @env = env
      end

      def perform
        authorize!

        env['response.post'] = Model::Post.import_notification(env)

        env
      rescue Model::Post::CreateFailure => e
        halt!(400, e.message)
      end

      private

      def halt!(status, message, attributes = {})
        raise Middleware::Halt.new(status, message, attributes)
      end

      def authorize!
        authorizer = Authorizer.new(env)
        unless (Hash === env['data']) && authorizer.write_authorized?(env['data']['entity'], env['data']['type'])
          halt!(403, "Unauthorized")
        end
      end
    end

  end
end
