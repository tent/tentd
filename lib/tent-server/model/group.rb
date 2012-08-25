module TentServer
  module Model
    class Group
      include DataMapper::Resource

      storage_names[:default] = "groups"

      property :id, Serial
      property :name, String
    end
  end
end
