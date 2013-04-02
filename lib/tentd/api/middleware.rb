require 'yajl'
module TentD
  class API

    class Middleware < Rack::Putty::Middleware

      class Halt < StandardError
        attr_accessor :code, :message
        def initialize(code, message)
          super(message)
          @code, @message = code, message
        end
      end

      def call(env)
        super
      rescue Halt => e
        [e.code, { 'Content-Type' => CONTENT_TYPE % "https://tent.io/types/error/v0#" }, [encode_json(:error => e.message)]]
      end

      def encode_json(data)
        Yajl::Encoder.encode(data)
      end

      def invalid_attributes!
        halt!(422, "Invalid Attributes")
      end

      def halt!(status, message)
        raise Halt.new(status, message)
      end

    end

  end
end
