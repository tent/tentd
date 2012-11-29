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
        self.notification_url = nil if notification_url.to_s == ''
        super
      end

      def after_save
        if scopes.to_a.map(&:to_s).include?('follow_ui') && follow_url
          q = AppAuthorization.qualify.join(:apps, :app_authorizations__app_id => :apps__id).where(
            :apps__user_id => app.user_id, :apps__deleted_at => nil
          ).where(Sequel.~(:follow_url => nil)).where("app_authorizations.scopes @> ARRAY['follow_ui']").where(
            Sequel.~(:app_authorizations__id => id)
          )
          _auths = q.all
          _auths.each { |a| a.update(:scopes => a.scopes - ['follow_ui']) }
        end
        super
      end

      def self.follow_url(entity)
        app_auth = qualify.join(:apps, :apps__id => :app_authorizations__app_id).where(:apps__user_id => User.current.id).where(Sequel.~(:app_authorizations__follow_url => nil)).order(:app_authorizations__id.desc).where("app_authorizations.scopes @> ARRAY['follow_ui']").first
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
          notification_subscriptions_dataset.where(:user_id => User.current.id).where(Sequel.~(:type_base => post_types.map { |t| TentType.new(t).base })).destroy

          data[:post_types].map { |t| TentType.new(t) }.each do |type|
            next if notification_subscriptions_dataset.first(:type_base => type.base)
            NotificationSubscription.create(:app_authorization_id => self.id, :type_base => type.base, :type_version => type.version, :type_view => type.view)
          end
        end

        saved
      end

      def token_exchange!(params = {})
        data = {
          :token_code => SecureRandom.hex(16)
        }
        data[:tent_expires_at] = params.tent_expires_at.to_i if params.tent_expires_at
        update(data)

        attrs = {
          :access_token => mac_key_id,
          :mac_key => mac_key,
          :mac_algorithm => mac_algorithm,
          :token_type => 'mac',
          :refresh_token => token_code
        }
        attrs[:tent_expires_at] = tent_expires_at if tent_expires_at
        attrs
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
