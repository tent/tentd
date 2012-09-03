require 'securerandom'

module TentD
  module Model
    class AppAuthorization
      include DataMapper::Resource

      storage_names[:default] = 'app_authorizations'

      property :id, Serial
      property :scopes, Array
      property :post_types, Array
      property :profile_info_types, Array, :default => [], :lazy => false
      property :scopes, Array, :default => []
      property :token_code, String
      property :mac_key_id, String, :default => lambda { |*args| 'u:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      property :token_type, String
      property :authorized, Boolean
      property :created_at, DateTime
      property :updated_at, DateTime

      belongs_to :app, 'TentD::Model::App'
      has n, :notification_subscriptions, 'TentD::Model::NotificationSubscription', :constraint => :destroy
    end
  end
end
