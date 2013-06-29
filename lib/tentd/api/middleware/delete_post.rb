module TentD
  class API

    class DeletePost < Middleware
      def action(env)
        return env unless post = env.delete('response.post')
        params = env['params']

        authorizer = Authorizer.new(env)
        unless authorizer.write_post?(post)
          if authorizer.read_authorized?(post)
            if authorizer.auth_candidate
              halt!(403, "Unauthorized")
            else
              halt!(401, "Unauthorized")
            end
          else
            halt!(404, "Not Found")
          end
        end

        delete_options = {}

        if env['HTTP_CREATE_DELETE_POST'] != "false" && post.entity_id == env['current_user'].entity_id
          delete_options[:create_delete_post] = true
        end

        if params[:version]
          delete_options[:delete_version] = params[:version]
        end

        post.user = env['current_user'] if post.user_id == env['current_user'].id # spare db lookup

        if delete_options[:create_delete_post]
          if delete_post = post.destroy(delete_options)
            env['response.post'] = delete_post
          else
            halt!(500, "Internal Server Error")
          end
        else
          if post.destroy(delete_options)
            env['response.status'] = 200
          else
            halt!(500, "Internal Server Error")
          end
        end

        env
      end
    end

  end
end
