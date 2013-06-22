module TentD
  class API

    class DeletePost < Middleware
      def action(env)
        return env unless post = env.delete('response.post')

        authorizer = Authorizer.new(env)
        if authorizer.write_post?(post)
          if env['HTTP_CREATE_DELETE_POST'] != "false"
            post.user = env['current_user'] if post.user_id == env['current_user'].id # spare db lookup
            if delete_post = post.destroy(:create_delete_post => true)
              env['response.post'] = delete_post
            else
              halt!(500, "Internal Server Error")
            end
          else
            if post.destroy
              env['response.status'] = 200
            else
              halt!(500, "Internal Server Error")
            end
          end
        else
          if authorizer.read_authorized?(post)
            halt!(403, "Unauthorized")
          else
            halt!(404, "Not Found")
          end
        end

        env
      end
    end

  end
end
