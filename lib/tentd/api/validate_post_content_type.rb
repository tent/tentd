module TentD
  class API

    class ValidatePostContentType < Middleware
      def action(env)
        unless valid_body?(env)
          halt!(400, "Request body missing.")
        end

        unless valid_content_type?(env)
          halt!(415, "Invalid Content-Type header. The header must be application/vnd.tent.post.v0+json.")
        end

        env
      end

      private

      def valid_body?(env)
        Hash === env['data']
      end

      def valid_content_type?(env)
        post_type = env['data']['type']
        env['CONTENT_TYPE'].to_s =~ Regexp.new("\\A#{Regexp.escape(POST_CONTENT_TYPE.split(';').first)}") &&
        env['CONTENT_TYPE'].to_s =~ Regexp.new(%(\\btype=["']#{Regexp.escape(post_type)}["']\\Z))
      end
    end

  end
end
