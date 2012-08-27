module TentServer
  module Model
    class Follow
      include DataMapper::Resource

      storage_names[:default] = 'follows'

      property :id, Serial
      property :groups, Array
      property :entity, URI
      property :profile, Json
      property :licenses, Array
      property :type, Enum[:following, :follower]
      timestamps :at

      has n, :notification_subscriptions, 'TentServer::Model::NotificationSubscription'
    end
  end
end
