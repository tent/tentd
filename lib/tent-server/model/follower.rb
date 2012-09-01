require 'tent-server/core_ext/hash/slice'
require 'securerandom'

module TentServer
  module Model
    class Follower
      include DataMapper::Resource
      include Permissible
      include RandomPublicUid

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

      def self.update_follower(id, data, authorized_scopes = [])
        follower = get(id)
        return unless follower
        whitelist = ['licenses']
        if authorized_scopes.include?(:write_followers)
          whitelist.concat(['entity', 'profile', 'public', 'groups'])

          if authorized_scopes.include?(:write_secrets)
            whitelist.concat(['mac_key_id', 'mac_key', 'mac_algorithm', 'mac_timestamp_delta'])
          end
        end
        follower.update(data.slice(*whitelist))
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

      def as_json(options = {})
        attributes = super
        attributes[:id] = public_uid if attributes[:id]
        attributes.delete(:public_uid)
        attributes
      end
    end
  end
end
