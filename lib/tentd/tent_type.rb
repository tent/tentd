module TentD
  class TentType
    attr_reader :version, :view, :uri

    def initialize(type_uri)
      @version = TentVersion.from_uri(type_uri)
      @view = type_uri.to_s.split('#')[1]
      @uri = type_uri.to_s.sub(%r{/v[^/]+$}, '')
    end
  end
end
