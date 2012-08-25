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
      property :mac_key_id, String
      property :mac_key, String
      property :mac_algorithm, String
      property :mac_timestamp_delta, Integer
      timestamps :at

      has n, :authorizations, 'TentServer::Model::AppAuthorization'
    end
  end
end
