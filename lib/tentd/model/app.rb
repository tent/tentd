require 'securerandom'
require 'tentd/core_ext/hash/slice'

module TentD
  module Model
    class App
      include DataMapper::Resource
      include RandomPublicId

      storage_names[:default] = 'apps'

      property :id, Serial
      property :name, String
      property :description, Text
      property :url, String
      property :icon, String
      property :redirect_uris, Array
      property :scopes, Json
      property :mac_key_id, String, :default => lambda { |*args| 'a:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :authorizations, 'TentD::Model::AppAuthorization', :constraint => :destroy

      def self.create_from_params(params)
        create(params.slice(:name, :description, :url, :icon, :redirect_uris, :scopes))
      end

      def self.update_from_params(id, params)
        app = get(id)
        return unless app
        app.update(params.slice(:name, :description, :url, :icon, :redirect_uris, :scopes))
        app
      end

      def auth_details
        attributes.slice(:mac_key_id, :mac_key, :mac_algorithm)
      end

      def as_json(options = {})
        authorized_scopes = options.delete(:authorized_scopes)
        attributes = super(options)
        attributes[:id] = attributes.delete(:public_id)
        blacklist = [:created_at, :updated_at]
        if authorized_scopes
          unless authorized_scopes.include?(:read_secrets)
            blacklist << [:mac_key, :mac_timestamp_delta]
          end
        end
        blacklist.flatten.each { |key| attributes.delete(key) }
        attributes
      end
    end
  end
end
