module TentD
  module Model

    class App < Sequel::Model(TentD.database[:apps])
      plugin :serialization
      serialize_attributes :pg_array, :read_post_types, :read_post_type_ids, :write_post_types
    end

  end
end
