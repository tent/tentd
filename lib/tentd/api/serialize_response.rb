require 'yajl'

module TentD
  class API

    module SerializeResponse
      extend self

      def call(env)
        if env.has_key?('response')
          [200, { 'Content-Type' => content_type(env['response']) }, [serialize(env['response'])]]
        else
          [201, {}, []]
        end
      end

      private

      def content_type(response_body)
        response_body = response_body.as_json
        POST_CONTENT_TYPE % (Hash === response_body ? response_body[:type] : "")
      end

      def serialize(response_body)
        Yajl::Encoder.encode(response_body.as_json)
      end
    end

  end
end
