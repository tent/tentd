module TentServer
  module Model
    class Permission
      include DataMapper::Resource

      storage_names[:default] = "permissions"

      belongs_to :post, 'TentServer::Model::Post', :required => false
      belongs_to :profile_info, 'TentServer::Model::ProfileInfo', :required => false
      belongs_to :group, 'TentServer::Model::Group', :required => false
      belongs_to :following, 'TentServer::Model::Following', :required => false
      belongs_to :follower_visibility, 'TentServer::Model::Follower', :required => false
      belongs_to :follower_access, 'TentServer::Model::Follower', :required => false
      belongs_to :app, 'TentServer::Model::App', :required => false
      belongs_to :app_authorization, 'TentServer::Model::AppAuthorization', :required => false

      property :id, Serial
      property :visible, Boolean
    end
  end
end
