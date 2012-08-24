module DataMapper
  class Property
    # Implements flat postgres string arrays
    class Array < String
      load_as ::Array

      def load(value)
        value[1..-2].split(',') if value
      end

      def dump(value)
        "{#{value.map(&:to_s).map(&:inspect).join(',')}}" if value
      end
    end
  end
end
