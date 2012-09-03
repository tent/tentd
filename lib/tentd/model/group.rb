module TentD
  module Model
    class Group
      include DataMapper::Resource
      include RandomPublicId

      storage_names[:default] = "groups"

      property :id, Serial
      property :name, String
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy, :parent_key => :public_id

      def as_json(options = {})
        attributes = super
        attributes[:id] = attributes.delete(:public_id)
        attributes
      end
    end
  end
end
