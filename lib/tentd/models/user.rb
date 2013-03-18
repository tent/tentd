module TentD
  module Model

    class User < Sequel::Model(TentD.database[:users])
    end

  end
end
