require 'securerandom'

module TentServer
  module Model
    class Post
      include DataMapper::Resource
      include Permissible
      include RandomPublicId

      storage_names[:default] = "posts"

      property :id, Serial
      property :entity, URI
      property :public, Boolean, :default => false
      property :type, URI
      property :licenses, Array
      property :content, Json
      property :published_at, DateTime
      property :received_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy
      has n, :attachments, 'TentServer::Model::PostAttachment', :constraint => :destroy

      def self.fetch_with_permissions(params, current_auth)
        super do |params, query, query_bindings|
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
        end
      end

      def can_notify?(app_or_follower)
        return true if public
        case app_or_follower
        when AppAuthorization
          app_or_follower.scopes && app_or_follower.scopes.include?(:read_posts) ||
          app_or_follower.post_types && app_or_follower.post_types.include?(type)
        when Follower
          (permissions.all(:group_public_id => app_or_follower.groups) +
           permissions.all(:follower_access_id => app_or_follower.id)).any?
        end
      end

      def as_json(options = {})
        attributes = super
        attributes[:id] = public_id if attributes[:id]
        attributes.delete(:public_id)
        attributes[:attachments] = attachments.all.map { |a| a.as_json }
        attributes
      end
    end
  end
end
