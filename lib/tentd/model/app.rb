require 'securerandom'
require 'tentd/core_ext/hash/slice'

module TentD
  module Model
    class App
      include DataMapper::Resource
      include RandomPublicId
      include Serializable
      include UserScoped

      storage_names[:default] = 'apps'

      property :id, Serial
      property :name, Text, :required => true, :lazy => false
      property :description, Text, :lazy => false
      property :url, Text, :required => true, :lazy => false
      property :icon, Text, :lazy => false
      property :redirect_uris, Array, :lazy => false, :default => []
      property :scopes, Json, :default => {}, :lazy => false
      property :mac_key_id, String, :default => lambda { |*args| 'a:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :authorizations, 'TentD::Model::AppAuthorization', :constraint => :destroy
      has n, :posts, 'TentD::Model::Post', :constraint => :set_nil
      has n, :post_versions, 'TentD::Model::PostVersion', :constraint => :set_nil

      def self.create_from_params(params)
        create(params.slice(:name, :description, :url, :icon, :redirect_uris, :scopes))
      end

      def self.update_from_params(id, params)
        app = first(:id => id)
        return unless app
        app.update(params.slice(:name, :description, :url, :icon, :redirect_uris, :scopes))
        app
      end

      def self.public_attributes
        [:name, :description, :url, :icon, :scopes, :redirect_uris]
      end

      def auth_details
        attributes.slice(:mac_key_id, :mac_key, :mac_algorithm)
      end

      def as_json(options = {})
        attributes = super

        if options[:mac]
          [:mac_key, :mac_key_id, :mac_algorithm].each { |key|
            attributes[key] = send(key)
          }
        end

        attributes[:authorizations] = authorizations.all.map { |a| a.as_json(options.merge(:self => nil)) }

        Array(options[:exclude]).each { |k| attributes.delete(k) if k }
        attributes
      end
    end
  end
end
