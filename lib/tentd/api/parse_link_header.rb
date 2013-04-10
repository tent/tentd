module TentD
  class API

    class ParseLinkHeader < Middleware

      def action(env)
        links = env['HTTP_LINK'].to_s.split(',')
        return env if links.empty?

        env['request.links'] = links.inject(Array.new) do |memo, link|
          parts = link.split(/;\s*/)
          url = parts.shift.to_s.slice(1...-1) # remove <>
          link = { :url => url }
          parts.each { |part|
            next unless part.downcase =~ /([a-z]+)=['"]([^'"]+)['"]/
            key, val = $1, $2
            link[key.to_sym] = val
          }
          memo << link
          memo
        end

        env
      end

    end

  end
end
