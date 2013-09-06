module TentD
  class API

    class CreatePostVersion < Middleware
      def action(env)
        TentD.logger.debug "CreatePostVersion#action" if TentD.settings[:debug]

        if env['request.notification']
          TentD.logger.debug "CreatePostVersion: notification request" if TentD.settings[:debug]

          case env['request.type'].to_s
          when "https://tent.io/types/relationship/v0#initial"
            TentD.logger.debug "CreatePostVersion -> RelationshipInitialization.call" if TentD.settings[:debug]

            RelationshipInitialization.call(env)
          else
            TentD.logger.debug "CreatePostVersion -> NotificationImporter.call" if TentD.settings[:debug]

            NotificationImporter.call(env)
          end
        else
          TentD.logger.debug "CreatePostVersion: create post version" if TentD.settings[:debug]

          unless Authorizer.new(env).write_post_id?(env['data']['entity'], env['data']['id'], env['data']['type'])
            TentD.logger.debug "CreatePostVersion: Unauthorized" if TentD.settings[:debug]

            if env['current_auth']
              halt!(403, "Unauthorized")
            else
              halt!(401, "Unauthorized")
            end
          end

          create_options = {}
          create_options[:import] = true if env['request.import']

          begin
            env['response.post'] = Model::Post.create_version_from_env(env, create_options)
          rescue Model::Post::CreateFailure => e
            TentD.logger.debug "CreatePostVersion: CreateFailure: #{e.inspect}" if TentD.settings[:debug]

            halt!(400, e.message)
          end
        end

        env
      end
    end

  end
end
