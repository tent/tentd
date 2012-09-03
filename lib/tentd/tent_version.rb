module TentD
  class TentVersion
    Infinity = 1 / 0.0

    include Comparable

    def self.from_uri(uri)
      new((uri.to_s.match(/v([.\dx]+)/) || [])[1])
    end

    def initialize(version_string)
      @version = version_string
    end

    def to_s
      @version
    end

    def parts
      @version.split('.').map { |p| p == 'x' ? p : p.to_i }
    end

    def parts=(array)
      @version = array.join('.')
    end

    def <=>(other)
      other = self.class.new(other) if other.kind_of?(String)
      parts.each_with_index.map { |p, index|
        if (p == 'x' || other.parts[index] == 'x') || p == other.parts[index]
          0
        elsif p < other.parts[index]
          -1
        elsif p > other.parts[index]
          1
        end
      }.each { |r| return r if r != 0 }
      0
    end
  end
end
