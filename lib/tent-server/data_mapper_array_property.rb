module DataMapper
  class Property
    # Implements flat postgres string arrays
    class Array < DataMapper::Property::Text
      def load(value)
        return value if value.kind_of? ::Array
        value[1..-2].split(',').map { |v| v[1..-2] } unless value.nil?
      end

      def dump(value)
        "{#{value.map(&:to_s).map(&:inspect).join(',')}}" unless value.nil?
      end

      def typecast(value)
        load(value)
      end
    end
  end
end
