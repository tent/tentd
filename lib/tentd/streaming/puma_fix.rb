# Fix Puma treating empty BodyProxies as non-empty
module Rack
  class BodyProxy
    def ==(other)
      if other == [] and @body == []
        true
      else
        super
      end
    end
  end
end
