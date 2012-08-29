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
        posts = find_by_sql(
          [
            "SELECT posts.* FROM posts INNER JOIN permissions ON permissions.post_id = posts.id AND (permissions.follower_access_id = ? OR permissions.group_id IN ?) WHERE posts.id = ?",
           current_auth.id.to_i, current_auth.groups, id.to_i
          ]
        )
        posts.first
      end
    end
  end
end
