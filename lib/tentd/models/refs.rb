module TentD
  module Model

    class Ref < Sequel::Model(TentD.database[:refs])
    end

  end
end
