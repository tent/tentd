require 'base64'

module DataMapper
  class Property
    # Implements flat postgres string arrays
    class BinaryString < DataMapper::Property::Text
      def custom?
        true
      end

      def load(value)
        Base64.decode64(value) if value
      end

      def dump(value)
        Base64.encode64(value) if value
      end

      def typecast(value)
        load(value)
      end
    end
  end
end
