require 'dm-ar-finders'
require 'securerandom'

module TentServer
  module Model
    class Post
      include DataMapper::Resource
      include Permissible
      include RandomPublicUid

      self.raise_on_save_failure = true

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

      def as_json(options = {})
        attributes = super
        attributes[:id] = public_uid if attributes[:id]
        attributes
      end
    end
  end
end
