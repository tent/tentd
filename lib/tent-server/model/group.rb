module TentServer
  module Model
    class Group
      include DataMapper::Resource
      include RandomUid

      storage_names[:default] = "groups"

      property :name, String
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy
    end
  end
end
