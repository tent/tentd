require 'yajl'
module TentD
  class API

    class Middleware < Rack::Putty::Middleware

      class Halt < StandardError
        attr_accessor :code, :message, :attributes
        def initialize(code, message, attributes = {})
          super(message)
          @code, @message, @attributes = code, message, attributes
        end
      end

      def call(env)
        super
      rescue Halt => e
        [e.code, { 'Content-Type' => ERROR_CONTENT_TYPE }, [encode_json(e.attributes.merge(:error => e.message))]]
      end

      def encode_json(data)
        Yajl::Encoder.encode(data)
      end

      def invalid_attributes!
        halt!(400, "Invalid Attributes")
      end

      def malformed_request!
        halt!(400, "Malformed Request")
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
