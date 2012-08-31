module TentServer
  module Model
    class Following
      include DataMapper::Resource
      include Permissible
      include RandomPublicUid

      storage_names[:default] = 'followings'

      property :id, Serial
      property :remote_id, String
      property :groups, Array
      property :entity, URI
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
          :entity => URI(params.entity),
          :groups => params.groups.to_a.map { |g| g['id'] },
          :mac_key_id => params.mac_key_id,
          :mac_key => params.mac_key,
          :mac_algorithm => params.mac_algorithm
        )
      end

      def as_json(options = {})
        attributes = super
        attributes[:id] = public_uid if attributes[:id]
        attributes
      end
    end
  end
end
