require 'securerandom'
require 'tentd/core_ext/hash/slice'

module TentD
  module Model
    class App < Sequel::Model(:apps)
      include RandomPublicId
      include Serializable

      plugin :paranoia
      plugin :serialization
      serialize_attributes :pg_array, :redirect_uris
      serialize_attributes :json, :scopes

      one_to_many :authorizations, :class => 'TentD::Model::AppAuthorization'
      one_to_many :posts
      one_to_many :post_versions

      def before_create
        self.public_id ||= random_id
        self.mac_key_id ||= 'a:' + random_id
        self.mac_key ||= SecureRandom.hex(16)
        self.mac_algorithm ||= 'hmac-sha-256'
        self.user_id ||= User.current.id
        self.created_at = Time.now
        super
      end

      def before_save
        self.updated_at = Time.now
        super
      end

      def self.create_from_params(params={})
        create(params.slice(*public_attributes))
      end

      def self.update_from_params(id, params)
        app = first(:id => id)
        return unless app
        app.update(params.slice(*public_attributes))
        app
      end

      def self.public_attributes
        [:name, :description, :url, :icon, :scopes, :redirect_uris, :created_at]
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

        attributes[:authorizations] = authorizations.map { |a| a.as_json(options.merge(:self => nil)) }

        Array(options[:exclude]).each { |k| attributes.delete(k) if k }
        attributes
      end
    end
  end
end
