module TentD
  class API

    class CreatePostVersion < Middleware
      def action(env)
        if env['request.notification']
          case env['request.type'].to_s
          when "https://tent.io/types/relationship/v0#initial"
            RelationshipInitialization.call(env)
          else
            NotificationImporter.call(env)
          end
        else
          unless Authorizer.new(env).write_authorized?(env['data']['entity'], env['data']['type'])
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
            halt!(400, e.message)
          end
        end

        env
      end
    end

  end
end
