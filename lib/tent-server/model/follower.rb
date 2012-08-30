require 'tent-server/core_ext/hash/slice'
require 'securerandom'
require 'hashie'

module TentServer
  module Model
    class Follower
      include DataMapper::Resource
      include Permissible

      storage_names[:default] = 'followers'

      property :id, Serial
      property :groups, Array
      property :entity, URI
      property :public, Boolean, :default => false
      property :profile, Json
      property :licenses, Array
      property :mac_key_id, String, :default => lambda { |*args| 's:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :notification_subscriptions, 'TentServer::Model::NotificationSubscription', :constraint => :destroy

      # permissions describing who can see them
      has n, :visibility_permissions, 'TentServer::Model::Permission', :child_key => [ :follower_visibility_id ], :constraint => :destroy

      # permissions describing what they have access too
      has n, :access_permissions, 'TentServer::Model::Permission', :child_key => [ :follower_access_id ], :constraint => :destroy

      def self.create_follower(data)
        follower = create(data.slice('entity', 'licenses', 'profile'))
        data['types'].each do |type_url|
          follower.notification_subscriptions.create(:type => URI(type_url))
        end
        follower
      end

      def self.update_follower(id, data)
        follower = get(id)
        follower.update(data.slice('licenses'))
        if data['types']
          if follower.notification_subscriptions.any?
            follower.notification_subscriptions.find(:type.not => [data['types']]).each(&:destroy)
          end
          data['types'].each do |type_url|
            follower.notification_subscriptions.create(:type => URI(type_url))
          end
        end
      end

      def permissible_foreign_key
        :follower_access_id
      end
    end
  end
end
