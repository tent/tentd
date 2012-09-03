require 'tentd/core_ext/hash/slice'
require 'securerandom'

module TentD
  module Model
    class Follower
      include DataMapper::Resource
      include Permissible
      include RandomPublicId

      storage_names[:default] = 'followers'

      property :id, Serial
      property :groups, Array
      property :entity, String
      property :public, Boolean, :default => false
      property :profile, Json
      property :licenses, Array
      property :mac_key_id, String, :default => lambda { |*args| 's:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :notification_subscriptions, 'TentD::Model::NotificationSubscription', :constraint => :destroy

      # permissions describing who can see them
      has n, :visibility_permissions, 'TentD::Model::Permission', :child_key => [ :follower_visibility_id ], :constraint => :destroy

      # permissions describing what they have access to
      has n, :access_permissions, 'TentD::Model::Permission', :child_key => [ :follower_access_id ], :constraint => :destroy

      def self.create_follower(data, authorized_scopes = [])
        if authorized_scopes.include?(:write_followers) && authorized_scopes.include?(:write_secrets)
          follower = create(data.slice(:entity, :groups, :public, :profile, :licenses, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta))
        else
          follower = create(data.slice('entity', 'licenses', 'profile'))
        end
        data.types.each do |type_url|
          follower.notification_subscriptions.create(:type => type_url)
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
            follower.notification_subscriptions.create(:type => type_url)
          end
        end
      end

      def permissible_foreign_key
        :follower_access_id
      end

      def as_json(options = {})
        authorized_scopes = options.delete(:authorized_scopes)
        attributes = super(options)
        attributes[:id] = public_id if attributes[:id]
        attributes.delete(:public_id)

        if authorized_scopes
          whitelist = [:id, :entity, :profile, :licenses]
          if authorized_scopes.include?(:read_followers)
            whitelist.concat([:public, :groups, :mac_key_id, :mac_algorithm])
            if authorized_scopes.include?(:read_secrets)
              whitelist.concat([:mac_key, :mac_algorithm, :mac_timestamp_delta])
            end
          end
          attributes.slice(*whitelist)
        else
          attributes
        end
      end
    end
  end
end
