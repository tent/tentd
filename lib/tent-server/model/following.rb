module TentServer
  module Model
    class Following
      include DataMapper::Resource
      include Permissible

      storage_names[:default] = 'followings'

      property :id, Serial
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

    end
  end
end
