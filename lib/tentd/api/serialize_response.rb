require 'yajl'

module TentD
  class API

    module SerializeResponse
      extend self

      def call(env)
        if env.has_key?('response')
          response_body = env['response'].as_json
          [200, { 'Content-Type' => content_type(response_body) }, [serialize(response_body)]]
        else
          [201, {}, []]
        end
      end

      private

      def content_type(response_body)
        POST_CONTENT_TYPE % (Hash === response_body ? response_body[:type] : "")
      end

      def serialize(response_body)
        Yajl::Encoder.encode(response_body)
      end
    end

  end
end
