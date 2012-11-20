require 'securerandom'
require 'tentd/core_ext/hash/slice'

module TentD
  module Model
    class AppAuthorization < Sequel::Model(:app_authorizations)
      include RandomPublicId
      include Serializable

      plugin :serialization
      serialize_attributes :pg_array, :post_types, :profile_info_types, :scopes

      one_to_many :notification_subscriptions
      many_to_one :app

      def before_create
        self.public_id ||= random_id
        self.token_code ||= SecureRandom.hex(16)
        self.mac_key_id ||= 'a:' + SecureRandom.hex(4)
        self.mac_key ||= SecureRandom.hex(16)
        self.mac_algorithm ||= 'hmac-sha-256'
        super
      end

      def before_save
        if scopes.to_a.map(&:to_s).include?('follow_ui') && follow_url
         # _auths = app.user.apps.authorizations.all(:follow_url.not => nil, :id.not => id)
         # _auths.each { |a| a.update(:scopes => a.scopes - ['follow_ui']) }
        end
        self.notification_url = nil if notification_url.to_s == ''
        super
      end

      def self.follow_url(entity)
        app_auth = where(Sequel.~(:follow_url => nil)).order(:id.desc).find { |a| a.scopes.map(&:to_sym).include?(:follow_ui) }
        return unless app_auth
        uri = URI(app_auth.follow_url)
        query = "entity=#{URI.encode_www_form_component(entity)}"
        uri.query ? uri.query += "&#{query}" : uri.query = query
        uri.to_s
      end

      def self.public_attributes
        [:post_types, :profile_info_types, :scopes, :notification_url]
      end

      def self.create_from_params(data)
        authorization = create(data)

        if data[:notification_url]
          data[:post_types].each do |type|
            NotificationSubscription.create(:app_authorization_id => authorization.id, :type => type)
          end
        end

        authorization
      end

      def update_from_params(data)
        _post_types = post_types

        saved = !!update(data.slice(*self.class.public_attributes))

        if saved && data[:post_types] && data[:post_types] != _post_types
          notification_subscriptions_dataset.where(Sequel.~(:type_base => post_types.map { |t| TentType.new(t).base })).destroy

          data[:post_types].map { |t| TentType.new(t) }.each do |type|
            next if notification_subscriptions_dataset.first(:type_base => type.base)
            NotificationSubscription.create(:app_authorization_id => self.id, :type_base => type.base, :type_version => type.version, :type_view => type.view)
          end
        end

        saved
      end

      def token_exchange!
        update(:token_code => SecureRandom.hex(16))
        {
          :access_token => mac_key_id,
          :mac_key => mac_key,
          :mac_algorithm => mac_algorithm,
          :token_type => 'mac'
        }
      end

      def auth_details
        attributes.slice(:mac_key_id, :mac_key, :mac_algorithm)
      end

      def notification_servers
        nil
      end

      def notification_path
        notification_url
      end

      def as_json(options = {})
        attributes = super

        if options[:authorization_token]
          attributes[:token_code] = token_code
        end

        attributes
      end
    end
  end
end

# module TentD
#   module Model
#     class AppAuthorization
#       include DataMapper::Resource
#       include RandomPublicId
#       include Serializable
#
#       storage_names[:default] = 'app_authorizations'
#
#       property :id, Serial
#       property :post_types, Array, :lazy => false, :default => []
#       property :profile_info_types, Array, :default => [], :lazy => false
#       property :scopes, Array, :default => [], :lazy => false
#       property :token_code, String, :default => lambda { |*args| SecureRandom.hex(16) }, :unique => true
#       property :mac_key_id, String, :default => lambda { |*args| 'u:' + SecureRandom.hex(4) }, :unique => true
#       property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
#       property :mac_algorithm, String, :default => 'hmac-sha-256'
#       property :mac_timestamp_delta, Integer
#       property :notification_url, Text, :lazy => false
#       property :follow_url, Text, :lazy => false
#       property :created_at, DateTime
#       property :updated_at, DateTime
#
#       belongs_to :app, 'TentD::Model::App'
#       has n, :notification_subscriptions, 'TentD::Model::NotificationSubscription', :constraint => :destroy
#
#     end
#   end
# end
