require 'yajl'

module TentD
  class API

    class ParseInputData < Middleware

      def action(env)
        return env unless %w( POST PUT ).include?(env['REQUEST_METHOD'])

        if data = rack_input(env)
          env['data'] = case env['CONTENT_TYPE'].split(';').first
          when /json\Z/
            Yajl::Parser.parse(data)
          when /\Amultipart/
            post_matcher = Regexp.new("\\A#{Regexp.escape(POST_CONTENT_TYPE.split(';').first)}\\b")
            data = (env['data'].find { |k,v| v[:type] =~ post_matcher } || []).last
            env['attachments'] = env['data'].reject { |k,v| v[:type] =~ post_matcher }.inject([]) { |memo, (category, attachment)|
              attachment[:headers] = parse_headers(attachment.delete(:head))
              attachment[:category] = category
              attachment[:name] = attachment[:filename]
              attachment[:content_type] = attachment.delete(:type)
              memo << attachment
              memo
            }
            env['CONTENT_TYPE'] = data[:type] if data
            data ? Yajl::Parser.parse(rack_input('rack.input' => data[:tempfile])) : nil
          else
            data
          end
        end

        env

      rescue Yajl::ParseError
        halt!(400, "Invalid JSON")
      end

      private

      def parse_headers(header_string)
        header_string.to_s.split(/$/).inject(Hash.new) do |memo, header|
          k,*v = header.chomp.strip.split(':')
          next memo unless k
          memo[k] = v.join.sub(/\A\s*/, '')
          memo
        end
      end

    end

  end
end
