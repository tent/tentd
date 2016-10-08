require 'yajl'
module TentD
  class API

    class Middleware < Rack::Putty::Middleware

      class Halt < StandardError
        attr_accessor :code, :message, :attributes, :headers
        def initialize(code, message, attributes = {})
          super(message)
          @code, @message, @attributes = code, message, attributes
          @headers = attributes.delete(:headers) || {}
        end
      end

      def call(env)
        super
      rescue Halt => e
        [e.code, { 'Content-Type' => ERROR_CONTENT_TYPE }.merge(e.headers), [encode_json(e.attributes.merge(:error => e.message))]]
      end

      def encode_json(data)
        Yajl::Encoder.encode(data)
      end

      def halt!(status, message, attributes = {})
        raise Halt.new(status, message, attributes)
      end

      def rack_input(env)
        data = env['rack.input'].read
        env['rack.input'].rewind
        data
      end

    end

  end
end
