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
