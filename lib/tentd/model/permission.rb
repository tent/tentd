module TentD
  module Model
    class Permission < Sequel::Model(:permissions)
      many_to_one :post
      many_to_one :group, :key => :group_public_id, :primary_key => :public_id
      many_to_one :following
      many_to_one :follower_visibility, :class => Follower
      many_to_one :follower_access, :class => Follower
      many_to_one :profile_info

      def self.copy(from, to)
        from.send(from.visibility_permissions_relationship_name).each do |permission|
          attrs = permission.attributes
          attrs.delete(:id)
          create(attrs.merge(
            to.visibility_permissions_relationship_foreign_key => to.id
          ))
        end
        to.update(:public => from.public)
      end
    end
  end
end

# module TentD
#   module Model
#     class Permission
#       include DataMapper::Resource
#
#       storage_names[:default] = "permissions"
#
#       belongs_to :post, 'TentD::Model::Post', :required => false
#       belongs_to :group, 'TentD::Model::Group', :required => false, :parent_key => :public_id
#       belongs_to :following, 'TentD::Model::Following', :required => false
#       belongs_to :follower_visibility, 'TentD::Model::Follower', :required => false
#       belongs_to :follower_access, 'TentD::Model::Follower', :required => false
#       belongs_to :profile_info, 'TentD::Model::ProfileInfo', :required => false
#
#       property :id, Serial
#       property :visible, Boolean, :default => true
#
#     end
#   end
# end
