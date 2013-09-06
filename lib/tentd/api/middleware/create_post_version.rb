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

          authorizer = Authorizer.new(env)
          entity, id, type = env['params']['entity'], env['params']['post'], env['data']['type']
          unless authorizer.write_post_id?(entity, id, type)
            TentD.logger.debug "CreatePostVersion: Unauthorized for write_post_id?(#{entity.inspect}, #{id.inspect}, #{type.inspect})" if TentD.settings[:debug]

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
