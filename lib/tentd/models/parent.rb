module TentD
  module Model

    class Parent < Sequel::Model(TentD.database[:parents])
    end

  end
end
