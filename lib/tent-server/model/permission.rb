module TentServer
  module Model
    class Permission
      include DataMapper::Resource

      storage_names[:default] = "permissions"

      belongs_to :post, 'TentServer::Model::Post', :required => false
      belongs_to :group, 'TentServer::Model::Group', :required => false, :parent_key => :public_uid
      belongs_to :following, 'TentServer::Model::Following', :required => false
      belongs_to :follower_visibility, 'TentServer::Model::Follower', :required => false
      belongs_to :follower_access, 'TentServer::Model::Follower', :required => false

      property :id, Serial
      property :visible, Boolean
    end
  end
end
