module TentD
  module Model

    class Type < Sequel::Model(TentD.database[:types])
    end

  end
end
