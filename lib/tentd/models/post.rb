module TentD
  module Model

    class Post < Sequel::Model(TentD.database[:posts])
      plugin :serialization
      serialize_attributes :pg_array, :permissions_entities, :permissions_groups
      serialize_attributes :json, :mentions, :attachments, :version_parents, :licenses, :content
    end

  end
end
