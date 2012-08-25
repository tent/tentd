module TentServer
  module Model
    class NotificationSubscription
      include DataMapper::Resource

      storage_names[:default] = 'notification_subscriptions'

      property :id, Serial
      property :type, URI
      property :view, String, :default => 'full'
      timestamps :at

      belongs_to :app_authorization, 'TentServer::Model::AppAuthorization', :required => false
      belongs_to :follow, 'TentServer::Model::Follow', :required => false
    end
  end
end
