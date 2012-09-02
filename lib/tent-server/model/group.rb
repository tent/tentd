module TentServer
  module Model
    class Group
      include DataMapper::Resource
      include RandomPublicUid

      storage_names[:default] = "groups"

      property :id, Serial
      property :name, String
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy, :parent_key => :public_uid

      def as_json(options = {})
        attributes = super
        attributes[:id] = attributes.delete(:public_uid)
        attributes
      end
    end
  end
end
