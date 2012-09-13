require 'securerandom'

module TentD
  module Model
    class Post
      include DataMapper::Resource
      include Permissible
      include RandomPublicId
      include Serializable
      include TypeProperties
      include UserScoped

      storage_names[:default] = "posts"

      property :id, Serial
      property :entity, Text, :lazy => false
      property :public, Boolean, :default => false
      property :licenses, Array, :default => []
      property :content, Json, :default => {}
      property :published_at, DateTime, :default => lambda { |*args| Time.now }
      property :received_at, DateTime, :default => lambda { |*args| Time.now }
      property :updated_at, DateTime
      property :app_name, Text, :lazy => false
      property :app_url, Text, :lazy => false
      property :original, Boolean, :default => false
      property :known_entity, Boolean

      has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy
      has n, :attachments, 'TentD::Model::PostAttachment', :constraint => :destroy
      has n, :mentions, 'TentD::Model::Mention', :constraint => :destroy
      belongs_to :app, 'TentD::Model::App', :required => false

      def self.create(data)
        mentions = data.delete(:mentions)
        post = super

        mentions.to_a.each do |mention|
          next unless mention[:entity]
          post.mentions.create(:entity => mention[:entity], :mentioned_post_id => mention[:post])
        end

        if post.mentions.to_a.any? && post.original
          post.mentions.each do |mention|
            follower = Follower.first(:entity => mention.entity)
            next if follower && NotificationSubscription.first(:follower => follower, :type_base => post.type.base)

            Notifications::NOTIFY_ENTITY_QUEUE << { :entity => mention.entity, :post_id => post.id }
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
              query << "AND posts.type_base IN ?"
              query_bindings << params.post_types.map { |t| TentType.new(t).base }
            end
          end

          if params.mentioned_post && params.mentioned_entity
            select = query.shift
            query.unshift "INNER JOIN mentions ON mentions.post_id = posts.id"
            query.unshift select

            query << "AND mentions.entity = ? AND mentions.mentioned_post_id = ?"
            query_bindings << params.mentioned_entity
            query_bindings << params.mentioned_post
          end
        end
      end

      def self.public_attributes
        [:app_name, :app_url, :entity, :type, :licenses, :content, :published_at]
      end

      def self.write_attributes
        public_attributes + [:known_entity, :original, :public, :mentions]
      end

      def can_notify?(app_or_follow)
        return true if public
        case app_or_follow
        when AppAuthorization
          app_or_follow.scopes && app_or_follow.scopes.map(&:to_sym).include?(:read_posts) ||
          app_or_follow.post_types && app_or_follow.post_types.include?(type.base)
        when Follower
          return false unless original
          q = permissions.all(:follower_access_id => app_or_follow.id)
          q += permissions.all(:group_public_id => app_or_follow.groups) if app_or_follow.groups.any?
          q.any?
        when Following
          return false unless original
          q = permissions.all(:following => app_or_follow)
          q += permissions.all(:group_public_id => app_or_follow.groups) if app_or_follow.groups.any?
          q.any?
        else
          false
        end
      end

      def as_json(options = {})
        attributes = super
        attributes[:type] = type.uri
        attributes[:app] = { :url => attributes.delete(:app_url), :name => attributes.delete(:app_name) }
        attributes[:attachments] = attachments.all.map { |a| a.as_json }

        attributes[:mentions] = mentions.map do |mention|
          h = { :entity => mention.entity }
          h[:post] = mention.mentioned_post_id if mention.mentioned_post_id
          h
        end

        if options[:app]
          attributes[:known_entity] = known_entity
        end

        Array(options[:exclude]).each { |k| attributes.delete(k) if k }
        attributes
      end
    end
  end
end
