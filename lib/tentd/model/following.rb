require 'tentd/core_ext/hash/slice'

module TentD
  module Model
    class Following
      include DataMapper::Resource
      include Permissible
      include RandomPublicId
      include Serializable
      include UserScoped

      storage_names[:default] = 'followings'

      property :id, Serial
      property :remote_id, String
      property :groups, Array, :lazy => false, :default => []
      property :entity, Text, :required => true, :lazy => false
      property :public, Boolean, :default => true
      property :profile, Json, :default => {}
      property :licenses, Array, :lazy => false, :default => []
      property :mac_key_id, String
      property :mac_key, String
      property :mac_algorithm, String
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime
      property :deleted_at, ParanoidDateTime
      property :confirmed, Boolean, :default => true

      has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy

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

      def self.public_attributes
        [:remote_id, :entity]
      end

      def self.update_profile(id)
        following = first(:id => id)
        return unless following
        following.update_profile
      end

      def update_profile
        client = TentClient.new(core_profile.servers, auth_details.merge(:faraday_adapter => TentD.faraday_adapter))
        res = client.profile.get
        if res.status == 200
          self.profile = res.body
          self.licenses = core_profile.licenses
          self.entity = core_profile.entity
        end
        save
        profile
      end

      def core_profile
        API::CoreProfileData.new(profile)
      end

      def notification_path
        'posts'
      end

      def notification_servers
        core_profile.servers
      end

      def auth_details
        attributes.slice(:mac_key_id, :mac_key, :mac_algorithm)
      end

      def update_from_params(params, authorized_scopes = [])
        whitelist = [:remote_id, :entity, :groups, :public, :licenses, :profile]
        if authorized_scopes.include?(:write_secrets)
          whitelist.concat([:mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta])
        end
        attributes = params.slice(*whitelist)
        update(attributes)
      end

      def as_json(options = {})
        attributes = super

        if options[:app]
          attributes[:profile] = profile
          attributes[:licenses] = licenses
        end

        attributes
      end
    end
  end
end
