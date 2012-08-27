module TentServer
  class TentVersion
    def self.from_uri(uri)
      new((uri.to_s.match(/v([.\dx]+)/) || [])[1])
    end

    def initialize(version_string)
      @version = version_string
    end

    def to_s
      @version
    end

    def ==(other)
      other = self.class.new(other) if other.kind_of?(String)
      return false unless other.kind_of?(self.class)
      parts.each_with_index do |p, index|
        return false if p != other.parts[index] && p != 'x'
      end
      true
    end

    def parts
      @version.split('.')
    end
  end
end
