require 'yajl'

module TentD
  class API

    class ParseInputData < Middleware

      def action(env)
        if data = rack_input(env)
          env['data'] = case env['CONTENT_TYPE'].split(';').first
          when /json\Z/
            Yajl::Parser.parse(data)
          else
            data
          end
        end

        env
      end

      private

      def rack_input(env)
        data = env['rack.input'].read
        env['rack.input'].rewind
        data
      end

    end

  end
end
