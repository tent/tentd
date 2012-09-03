module TentD
  module Model
    class Permission
      include DataMapper::Resource

      storage_names[:default] = "permissions"

      belongs_to :post, 'TentD::Model::Post', :required => false
      belongs_to :group, 'TentD::Model::Group', :required => false, :parent_key => :public_id
      belongs_to :following, 'TentD::Model::Following', :required => false
      belongs_to :follower_visibility, 'TentD::Model::Follower', :required => false
      belongs_to :follower_access, 'TentD::Model::Follower', :required => false

      property :id, Serial
      property :visible, Boolean
    end
  end
end
