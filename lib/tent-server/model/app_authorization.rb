module TentServer
  module Model
    class AppAuthorization
      include DataMapper::Resource

      storage_names[:default] = 'app_authorizations'

      property :id, Serial
      property :scopes, Array
      property :post_types, Array
      property :profile_info_types, Array
      property :token_code, String
      property :access_token, String
      property :mac_key, String
      property :mac_algorithm, String
      property :mac_timestamp_delta, Integer
      property :token_type, String
      property :authorized, Boolean
      timestamps :at

      belongs_to :app, 'TentServer::Model::App'
      has n, :notification_subscriptions, 'TentServer::Model::NotificationSubscription'
    end
  end
end
