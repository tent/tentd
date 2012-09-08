require 'securerandom'

module TentD
  module Model
    class Post
      include DataMapper::Resource
      include Permissible
      include RandomPublicId
      include Serializable
      include TypeProperties

      storage_names[:default] = "posts"

      property :id, Serial
      property :entity, String
      property :public, Boolean, :default => false
      property :licenses, Array, :default => []
      property :content, Json, :default => {}
      property :mentions, Json, :default => [], :lazy => false
      property :published_at, DateTime, :default => lambda { |*args| Time.now }
      property :received_at, DateTime, :default => lambda { |*args| Time.now }
      property :updated_at, DateTime
      property :app_name, String
      property :app_url, String
      property :original, Boolean, :default => false
      property :known_entity, Boolean

      has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy
      has n, :attachments, 'TentD::Model::PostAttachment', :constraint => :destroy
      belongs_to :app, 'TentD::Model::App', :required => false

      def self.create(data)
        post = super

        if post.mentions != [] && post.original
          post.mentions.each do |mention|
            follower = Follower.first(:entity => mention[:entity])
            next if follower && NotificationSubscription.first(:follower => follower, :type => post.type)

            Notifications::NOTIFY_ENTITY_QUEUE << { :entity => mention[:entity], :post_id => post.id }
          end
        end

        post
      end

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

      def self.public_attributes
        [:app_name, :app_url, :entity, :type, :licenses, :content, :published_at]
      end

      def self.write_attributes
        public_attributes + [:known_entity, :original, :public, :mentions]
      end

      def can_notify?(app_or_follower)
        return true if public
        case app_or_follower
        when AppAuthorization
          app_or_follower.scopes && app_or_follower.scopes.map(&:to_sym).include?(:read_posts) ||
          app_or_follower.post_types && app_or_follower.post_types.include?(type)
        when Follower
          return false unless original
          (permissions.all(:group_public_id => app_or_follower.groups) +
           permissions.all(:follower_access_id => app_or_follower.id)).any?
        end
      end

      def as_json(options = {})
        attributes = super
        attributes[:app] = { :url => attributes.delete(:app_url), :name => attributes.delete(:app_name) }
        attributes[:attachments] = attachments.all.map { |a| a.as_json }

        if options[:app]
          attributes[:known_entity] = known_entity
        end

        Array(options[:exclude]).each { |k| attributes.delete(k) if k }
        attributes
      end
    end
  end
end
