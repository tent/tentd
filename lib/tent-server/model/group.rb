module TentServer
  module Model
    class Group
      include DataMapper::Resource

      storage_names[:default] = "groups"

      property :id, Serial
      property :name, String

      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy
    end
  end
end
