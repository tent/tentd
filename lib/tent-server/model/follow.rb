require 'tent-server/core_ext/hash/slice'

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
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :notification_subscriptions, 'TentServer::Model::NotificationSubscription'

      class << self
        def create_follower(data)
          follower = create(data.slice('entity', 'licenses', 'profile').merge(:type => :follower))
          data['types'].each do |type_url|
            follower.notification_subscriptions.create(:type => URI(type_url))
          end
          follower
        end
      end
    end
  end
end
