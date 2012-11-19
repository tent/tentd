module TentD
  module Model
    class Group < Sequel::Model(:groups)
      include RandomPublicId
      include Serializable

      one_to_many :permissions

      def before_create
        self.public_id ||= random_id
        self.user_id ||= User.current.id
      end
    end
  end
end

# module TentD
#   module Model
#     class XGroup
#       include DataMapper::Resource
#       include RandomPublicId
#       include Serializable
#       include UserScoped
#
#       storage_names[:default] = "groups"
#
#       property :id, Serial
#       property :name, Text, :required => true, :lazy => false
#       property :created_at, DateTime
#       property :updated_at, DateTime
#       property :deleted_at, ParanoidDateTime
#
#       has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy, :parent_key => :public_id
#
#       def self.public_attributes
#         [:name]
#       end
#     end
#   end
# end
