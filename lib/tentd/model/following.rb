require 'tentd/core_ext/hash/slice'

module TentD
  module Model
    class Following
      include DataMapper::Resource
      include Permissible
      include RandomPublicId
      include Serializable

      storage_names[:default] = 'followings'

      property :id, Serial
      property :remote_id, String
      property :groups, Array, :lazy => false, :default => []
      property :entity, String, :required => true
      property :public, Boolean, :default => false
      property :profile, Json, :default => {}
      property :licenses, Array, :lazy => false, :default => []
      property :mac_key_id, String
      property :mac_key, String
      property :mac_algorithm, String
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy

      def self.create_from_params(params)
        create(
          :remote_id => params.id,
          :entity => params.entity,
          :groups => params.groups.to_a.map { |g| g['id'] },
          :mac_key_id => params.mac_key_id,
          :mac_key => params.mac_key,
          :mac_algorithm => params.mac_algorithm
        )
      end

      def self.public_attributes
        [:remote_id, :entity]
      end

      def core_profile
        API::CoreProfileData.new(profile)
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
