module TentD
  class API

    class NotificationImporter
      def self.call(env)
        TentD.logger.debug "NotificationImporter.call" if TentD.settings[:debug]

        new(env).perform
      end

      attr_reader :env
      def initialize(env)
        @env = env
      end

      def perform
        TentD.logger.debug "NotificationImporter#perform" if TentD.settings[:debug]

        authorize!

        TentD.logger.debug "NotificationImporter -> Post.import_notification" if TentD.settings[:debug]

        env['response.post'] = Model::Post.import_notification(env)

        env
      rescue Model::Post::CreateFailure => e
        TentD.logger.debug "NotificationImporter: CreateFailure: #{e.inspect}" if TentD.settings[:debug]

        halt!(400, e.message)
      end

      private

      def halt!(status, message, attributes = {})
        raise Middleware::Halt.new(status, message, attributes)
      end

      def authorize!
        authorizer = Authorizer.new(env)
        unless (Hash === env['data']) && authorizer.write_authorized?(env['data']['entity'], env['data']['type'])
          TentD.logger.debug "NotificationImporter: Unauthorized" if TentD.settings[:debug]

          halt!(403, "Unauthorized")
        end
      end
    end

  end
end
