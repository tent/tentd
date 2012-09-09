module TentD
  class TentType
    attr_accessor :version, :view, :base

    def initialize(uri = nil)
      if uri
        @version = TentVersion.from_uri(uri)
        view_split = uri.to_s.split('#')
        @view = view_split[1]
        @base = view_split[0].to_s.sub(%r{/v[^a-z/][^/]*$}, '')
      end
    end

    def uri
      version_part = @version.nil? ? '' : "/v#{@version}"
      view_part = @view.nil? ? '' : "##{@view}"
      "#{@base}#{version_part}#{view_part}"
    end
  end
end
