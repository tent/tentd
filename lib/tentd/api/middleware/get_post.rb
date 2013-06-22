module TentD
  class API

    class GetPost < Middleware
      def action(env)
        if post = env['response.post']
          halt!(404, "Not Found") unless post && Authorizer.new(env).read_authorized?(post)

          case env['HTTP_ACCEPT']
          when MENTIONS_CONTENT_TYPE
            return ListPostMentions.new(@app).call(env)
          when CHILDREN_CONTENT_TYPE
            return ListPostChildren.new(@app).call(env)
          when VERSIONS_CONTENT_TYPE
            return ListPostVersions.new(@app).call(env)
          end
        end

        env
      end
    end

  end
end
