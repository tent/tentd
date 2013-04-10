module TentD
  module Model

    class Mention < Sequel::Model(TentD.database[:mentions])
    end

  end
end
