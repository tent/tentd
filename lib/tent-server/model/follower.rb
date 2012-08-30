require 'tent-server/core_ext/hash/slice'
require 'securerandom'
require 'hashie'

module TentServer
  module Model
    class Follower
      include DataMapper::Resource
      include Permissible

      storage_names[:default] = 'followers'

      property :id, Serial
      property :groups, Array
      property :entity, URI
      property :public, Boolean, :default => false
      property :profile, Json
      property :licenses, Array
      property :mac_key_id, String, :default => lambda { |*args| 's:' + SecureRandom.hex(4) }, :unique => true
      property :mac_key, String, :default => lambda { |*args| SecureRandom.hex(16) }
      property :mac_algorithm, String, :default => 'hmac-sha-256'
      property :mac_timestamp_delta, Integer
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :notification_subscriptions, 'TentServer::Model::NotificationSubscription', :constraint => :destroy

      # permissions describing who can see them
      has n, :visibility_permissions, 'TentServer::Model::Permission', :child_key => [ :follower_visibility_id ], :constraint => :destroy

      # permissions describing what they have access too
      has n, :access_permissions, 'TentServer::Model::Permission', :child_key => [ :follower_access_id ], :constraint => :destroy

      def self.create_follower(data)
        follower = create(data.slice('entity', 'licenses', 'profile'))
        data['types'].each do |type_url|
          follower.notification_subscriptions.create(:type => URI(type_url))
        end
        follower
      end

      def self.update_follower(id, data)
        follower = get(id)
        follower.update(data.slice('licenses'))
        if data['types']
          if follower.notification_subscriptions.any?
            follower.notification_subscriptions.find(:type.not => [data['types']]).each(&:destroy)
          end
          data['types'].each do |type_url|
            follower.notification_subscriptions.create(:type => URI(type_url))
          end
        end
      end

      def self.fetch_with_permissions(params, current_auth)
        params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)

        query = []
        query_bindings = []

        query << "SELECT followers.* FROM followers"

        if current_auth && current_auth.respond_to?(:permissible_foreign_key)
          query << "LEFT OUTER JOIN permissions ON permissions.follower_visibility_id = followers.id"
          query << "AND (permissions.#{current_auth.permissible_foreign_key} = ?"
          query_bindings << current_auth.id
          if current_auth.respond_to?(:groups) && current_auth.groups.to_a.any?
            query << "OR permissions.group_id IN ?)"
            query_bindings << current_auth.groups
          else
            query << ")"
          end

          query << "WHERE (followers.id = permissions.follower_visibility_id OR followers.public = ?)"
          query_bindings << true
        else
          query << "WHERE public = ?"
          query_bindings << true
        end

        if params.since_id
          query << "AND followers.id > ?"
          query_bindings << params.since_id.to_i
        end

        if params.before_id
          query << "AND followers.id < ?"
          query_bindings << params.before_id.to_i
        end

        query << "LIMIT ?"
        query_bindings << [(params.limit ? params.limit.to_i : TentServer::API::PER_PAGE), TentServer::API::MAX_PER_PAGE].min

        find_by_sql([query.join(' '), *query_bindings])
      end

      def permissible_foreign_key
        :follower_access_id
      end
    end
  end
end
