module TentD
  module Model

    class Ref < Sequel::Model(TentD.database[:refs])
      plugin :paranoia if Model.soft_delete
    end

  end
end
