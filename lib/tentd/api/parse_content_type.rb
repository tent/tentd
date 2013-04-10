module TentD
  class API

    class ParseContentType < Middleware

      def action(env)
        return env unless env['CONTENT_TYPE']

        ##
        # Parse post type
        if env['CONTENT_TYPE'] =~ /\btype=['"]([^'"]+)['"]/
          env['request.type'] = TentType.new($1)
        end

        ##
        # Parse rel
        env['request.rel'] = (env['CONTENT_TYPE'].match(/\brel=['"]([^'"]+)['"]/) || [])[1]

        case env['request.rel']
        when "https://tent.io/rels/notification"
          env['request.notification'] = true
        end

        ##
        # Parse type
        env['request.mime'] = env['CONTENT_TYPE'].to_s.split(';').first

        env
      end

    end

  end
end
