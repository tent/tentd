require 'securerandom'
require 'tent-server/core_ext/hash/slice'

module TentServer
  module Model
    class App
      include DataMapper::Resource

      storage_names[:default] = 'apps'

      property :id, Serial
      property :name, String
      property :description, Text
      property :url, URI
      property :icon, URI
      property :redirect_uris, Array
      property :scopes, Json
      property :mac_key_id, String, :default => lambda { |*args| 'a:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :authorizations, 'TentServer::Model::AppAuthorization', :constraint => :destroy
      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy

      def self.create_from_params(params)
        create(params.slice(:name, :description, :url, :icon, :redirect_uris, :scopes))
      end

      def self.update_from_params(id, params)
        app = get(id)
        return unless app
        app.update(params.slice(:name, :description, :url, :icon, :redirect_uris, :scopes))
        app
      end
    end
  end
end
