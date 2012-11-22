require 'tentd/core_ext/hash/slice'
require 'securerandom'

module TentD
  module Model
    class Follower < Sequel::Model(:followers)
      include RandomPublicId
      include Serializable
      include Permissible

      plugin :paranoia
      plugin :serialization
      serialize_attributes :pg_array, :groups, :licenses
      serialize_attributes :json, :profile

      one_to_many :notification_subscriptions

      # permissions describing who can see them
      one_to_many :visibility_permissions, :key => :follower_visibility_id, :class => Permission

      # permissions describing what they have access to
      one_to_many :access_permissions, :key => :follower_access_id, :class => Permission

      def before_create
        self.public_id ||= random_id
        self.mac_key_id ||= 's:' + SecureRandom.hex(4)
        self.mac_key ||= SecureRandom.hex(16)
        self.mac_algorithm ||= 'hmac-sha-256'
        self.user_id ||= User.current.id
        self.created_at = Time.now
        super
      end

      def before_save
        self.updated_at = Time.now
        super
      end

      def permissible_foreign_key
        :follower_access_id
      end

      def self.public_attributes
        [:entity]
      end

      def self.create_follower(data, authorized_scopes = [])
        existing_followers = where(:entity => data.entity)
        if existing_followers.any?
          existing_followers.destroy
        end

        if authorized_scopes.include?(:write_followers) && authorized_scopes.include?(:write_secrets)
          follower = create(data.slice(:public_id, :entity, :groups, :public, :profile, :licenses, :notification_path, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta))
          if data.permissions
            follower.assign_permissions(data.permissions)
          end
        else
          follower = create(data.slice('entity', 'licenses', 'profile', 'notification_path'))
        end
        (data.types || ['all']).each do |type_url|
          NotificationSubscription.create(
            :follower => follower,
            :type => type_url
          )
        end
        follower
      end

      def self.update_follower(id, data, authorized_scopes = [])
        follower = first(:id => id)
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
          follower.notification_subscriptions_dataset.destroy
          data['types'].each do |type_url|
            NotificationSubscription.create(
              :follower_id => follower.id,
              :type => type_url
            )
          end
        end
        follower
      end

      def self.update_entity(follower_id)
        first(:id => follower_id).update_entity
      end

      def update_entity
        client = TentClient.new(core_profile.servers, auth_details.merge(:faraday_adapter => TentD.faraday_adapter))
        res = client.profile.get
        old_entity = self.entity
        if res.status == 200
          self.profile = res.body
          self.licenses = core_profile.licenses
          self.entity = core_profile.entity
          save
        end
        propagate_entity(self.entity, old_entity) if self.entity != old_entity
        profile
      end

      def propagate_entity(new_entity, old_entity)
        Post.where(:user_id => User.current.id, :entity => old_entity, :original => false).update(:entity => entity)
        Mention.from(:mentions, :posts).where(:posts__user_id => User.current.id, :mentions__entity => old_entity, :mentions__original_post => false).update(:entity => entity)
      end

      def public?
        !!self.public
      end

      def auth_details
        attributes.slice(:mac_key_id, :mac_key, :mac_algorithm)
      end

      def core_profile
        API::CoreProfileData.new(profile)
      end

      def notification_servers
        core_profile.servers
      end

      def as_json(options = {})
        attributes = super

        attributes.merge!(:profile => profile) if options[:app]

        if options[:app] || options[:self]
          types = notification_subscriptions.map { |s| s.type.uri }
          attributes.merge!(:licenses => licenses, :types => types, :notification_path => notification_path)
        end

        attributes
      end
    end
  end
end
