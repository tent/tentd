require 'tentd/core_ext/hash/slice'
require 'tentd/model'

module TentD
  module Model
    class Following < Sequel::Model(:followings)
      include RandomPublicId
      include Serializable
      include Permissible

      plugin :paranoia
      plugin :serialization
      serialize_attributes :pg_array, :groups, :licenses
      serialize_attributes :json, :profile

      one_to_many :permissions

      def before_create
        self.public_id ||= random_id
        self.user_id ||= User.current.id
        self.created_at = Time.now
        super
      end

      def before_save
        self.updated_at = Time.now
        super
      end

      def self.public_attributes
        [:entity]
      end

      def self.update_profile(id)
        following = first(:id => id)
        return unless following
        following.update_profile
      end

      def update_profile
        client = TentClient.new(core_profile.servers, auth_details.merge(:faraday_adapter => TentD.faraday_adapter))
        res = client.profile.get
        old_entity = self.entity
        if res.status == 200
          self.profile = res.body
          self.licenses = core_profile.licenses
          self.entity = core_profile.entity
          save
        end
        propagate_entity(self.entity, old_entity) if old_entity != self.entity
        profile
      end

      def propagate_entity(entity, old_entity)
        Post.where(:user_id => user_id, :entity => old_entity, :original => false).update(:entity => entity)
        Mention.from(:mentions, :posts).where(:posts__user_id => user_id, :mentions__entity => old_entity).update(:entity => entity)
      end

      def update_from_params(params, authorized_scopes = [])
        whitelist = [:remote_id, :entity, :groups, :public, :licenses, :profile]
        if authorized_scopes.include?(:write_secrets)
          whitelist.concat([:mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta])
        end
        attributes = params.slice(*whitelist)
        update(attributes)
      end

      def confirm_from_params(params)
        update(
          :remote_id => params.id,
          :profile => params.profile || {},
          :mac_key_id => params.mac_key_id,
          :mac_key => params.mac_key,
          :mac_algorithm => params.mac_algorithm,
          :entity => API::CoreProfileData.new(params.profile || {}).entity,
          :confirmed => true
        )
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

      def notification_path
        'posts'
      end

      def as_json(options = {})
        attributes = super

        if options[:app]
          attributes[:profile] = profile
          attributes[:licenses] = licenses
          attributes[:remote_id] = remote_id
        end

        attributes
      end
    end
  end
end
