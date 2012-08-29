require 'securerandom'

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
      property :scope_descriptions, Json
      property :mac_key_id, String, :default => lambda { |*args| 'a:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      timestamps :at

      has n, :authorizations, 'TentServer::Model::AppAuthorization', :constraint => :destroy
      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy
    end
  end
end
