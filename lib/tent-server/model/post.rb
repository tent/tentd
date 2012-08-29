require 'dm-ar-finders'
require 'hashie'

module TentServer
  module Model
    class Post
      include DataMapper::Resource

      storage_names[:default] = "posts"

      property :id, Serial
      property :entity, URI
      property :scope, Enum[:public, :limited, :direct], :default => :direct
      property :public, Boolean, :default => false
      property :type, URI
      property :licenses, Array
      property :content, Json
      property :published_at, DateTime
      property :received_at, DateTime

      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy

      def self.find_with_permissions(id, current_auth)
        query = []
        query_bindings = []

        permissible_key = case current_auth
        when Follower
          'follower_access_id'
        when AppAuthorization
          'app_authorization_id'
        when App
          'app_id'
        end

        query << "SELECT posts.* FROM posts INNER JOIN permissions ON permissions.post_id = posts.id"
        query << "AND (permissions.#{permissible_key} = ?"
        query_bindings << current_auth.id
        if current_auth.respond_to?(:groups) && current_auth.groups.to_a.any?
          query << "OR permissions.group_id IN ?)"
          query_bindings << current_auth.groups
        else
          query << ")"
        end
        query << "WHERE posts.id = ?"
        query_bindings << id
        posts = find_by_sql(
          [query.join(' '), *query_bindings]
        )
        posts.first
      end

      def self.fetch_with_permissions(params, current_auth)
        query = []
        query_bindings = []
        params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)

        query << "SELECT posts.* FROM posts"

        if current_auth
          query << "LEFT OUTER JOIN permissions ON permissions.post_id = posts.id"
          query << "AND (permissions.#{current_auth.permissible_foreign_key} = ?"
          query_bindings << current_auth.id
          query << ")"
          query << "WHERE (public = ? OR permissions.post_id = posts.id)"
          query_bindings << true
        else
          query << "WHERE public = ?"
          query_bindings << true
        end

        if params.since_id
          query << "AND posts.id > ?"
          query_bindings << params.since_id
        end

        if params.before_id
          query << "AND posts.id < ?"
          query_bindings << params.before_id
        end

        if params.since_time
          query << "AND posts.published_at > ?"
          query_bindings << Time.at(params.since_time.to_i)
        end

        if params.before_time
          query << "AND posts.published_at < ?"
          query_bindings << Time.at(params.before_time.to_i)
        end

        if params.post_types
          params.post_types = params.post_types.split(',').map { |url| URI.unescape(url) }
          if params.post_types.any?
            query << "AND posts.type IN ?"
            query_bindings << params.post_types
          end
        end

        query << "LIMIT ?"
        query_bindings << (params.limit ? [params.limit.to_i, TentServer::API::MAX_PER_PAGE].min : TentServer::API::PER_PAGE)

        find_by_sql([query.join(' '), *query_bindings])
      end
    end
  end
end
