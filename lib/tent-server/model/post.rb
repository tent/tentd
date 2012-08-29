require 'dm-ar-finders'

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
    end
  end
end
