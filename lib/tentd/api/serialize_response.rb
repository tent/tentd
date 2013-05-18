require 'yajl'

module TentD
  class API

    module SerializeResponse
      extend self

      def call(env)
        response_headers = build_response_headers(env)
        if env.has_key?('response') && env['response']
          response_body = env['response'].as_json
          [env['response.status'] || 200, { 'Content-Type' => content_type(response_body) }.merge(response_headers), [serialize(response_body)]]
        else
          [env['response.status'] || 404, { 'Content-Type' => ERROR_CONTENT_TYPE }.merge(response_headers), [serialize(:error => 'Not Found')]]
        end
      end

      private

      def build_response_headers(env)
        headers = (env['response.headers'] || Hash.new)

        links = (env['response.links'] || Array.new).map do |link|
          _link = "<#{link.delete(:url)}>"
          if link.keys.any?
            _link << link.inject([nil]) { |memo, (k,v)| memo << %(#{k}=#{v.inspect}); memo }.join("; ")
          end
          _link
        end

        if links.any?
          links = links.join(', ')
          headers['Link'] ? headers['Link'] << ", #{links}" : headers['Link'] = links
        end

        headers
      end

      def content_type(response_body)
        POST_CONTENT_TYPE % (Hash === response_body ? response_body[:type] : "")
      end

      def serialize(response_body)
        Yajl::Encoder.encode(response_body)
      end
    end

  end
end
