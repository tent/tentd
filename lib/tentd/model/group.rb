module TentD
  module Model
    class Group
      include DataMapper::Resource
      include RandomPublicId
      include Serializable

      storage_names[:default] = "groups"

      property :id, Serial
      property :name, Text, :required => true, :lazy => false
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy, :parent_key => :public_id

      def self.public_attributes
        [:name]
      end
    end
  end
end
