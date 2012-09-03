require 'tent-server/core_ext/hash/slice'

module TentServer
  module Model
    class Following
      include DataMapper::Resource
      include Permissible
      include RandomPublicId

      storage_names[:default] = 'followings'

      property :id, Serial
      property :remote_id, String
      property :groups, Array
      property :entity, String
      property :public, Boolean, :default => false
      property :profile, Json
      property :licenses, Array
      property :mac_key_id, String
      property :mac_key, String
      property :mac_algorithm, String
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy

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

      def core_profile
        API::CoreProfileData.new(profile)
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
        authorized_scopes = options.delete(:authorized_scopes).to_a
        attributes = super(options)
        attributes[:id] = public_id if attributes[:id]
        attributes.delete(:public_id)
        blacklist = [:created_at, :updated_at]
        unless authorized_scopes.include?(:read_followings) && authorized_scopes.include?(:read_secrets)
          blacklist.concat([:mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta])
        end
        blacklist.each { |key| attributes.delete(key) }
        attributes
      end
    end
  end
end
