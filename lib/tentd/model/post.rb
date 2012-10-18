require 'securerandom'

module TentD
  module Model
    class Post
      include DataMapper::Resource
      include Permissible
      include PermissiblePost
      include RandomPublicId
      include Serializable
      include TypeProperties
      include UserScoped

      storage_names[:default] = "posts"

      property :id, Serial
      property :entity, Text, :lazy => false, :unique_index => :upublic_id
      property :public, Boolean, :default => false
      property :licenses, Array, :default => []
      property :content, Json, :default => {}
      property :views, Json, :default => {}
      property :published_at, DateTime, :default => lambda { |*args| Time.now }
      property :received_at, DateTime, :default => lambda { |*args| Time.now }
      property :updated_at, DateTime
      property :deleted_at, ParanoidDateTime
      property :app_name, Text, :lazy => false
      property :app_url, Text, :lazy => false
      property :original, Boolean, :default => false

      has n, :permissions, 'TentD::Model::Permission', :constraint => :destroy
      has n, :attachments, 'TentD::Model::PostAttachment', :constraint => :destroy
      has n, :mentions, 'TentD::Model::Mention', :constraint => :destroy
      belongs_to :app, 'TentD::Model::App', :required => false
      belongs_to :following, 'TentD::Model::Following', :required => false

      has n, :versions, 'TentD::Model::PostVersion', :constraint => :destroy

      after :create, :create_version!

      def create_version!(post = self)
        attrs = post.attributes
        attrs.delete(:id)
        latest = post.versions.all(:order => :version.desc, :fields => [:version]).first
        attrs[:version] = latest ? latest.version + 1 : 1
        version = post.versions.create(attrs)
      end

      def latest_version(options = {})
        versions.all({ :order => :version.desc }.merge(options)).first
      end

      def update(data)
        mentions = data.delete(:mentions)
        last_version = latest_version(:fields => [:id])
        res = super(data)

        create_version! # after update hook doe not fire

        current_version = latest_version(:fields => [:id])

        if mentions.to_a.any?
          Mention.all(:post_id => self.id).update(:post_id => nil, :post_version_id => last_version.id)
          mentions.each do |mention|
            next unless mention[:entity]
            self.mentions.create(:entity => mention[:entity], :mentioned_post_id => mention[:post], :original_post => self.original, :post_version_id => current_version.id)
          end
        end

        res
      end

      def self.create(data)
        data[:published_at] = Time.at(data[:published_at].to_time.to_i / 1000) if data[:published_at] && ((data[:published_at].to_time.to_i - Time.now.to_i) > 1000000000)
        mentions = data.delete(:mentions)
        post = super(data)

        mentions.to_a.each do |mention|
          next unless mention[:entity]
          post.mentions.create(:entity => mention[:entity], :mentioned_post_id => mention[:post], :original_post => post.original, :post_version_id => post.latest_version(:fields => [:id]).id)
        end

        if post.mentions.to_a.any? && post.original
          post.mentions.each do |mention|
            follower = Follower.first(:entity => mention.entity)
            next if follower && NotificationSubscription.first(:follower => follower, :type_base => post.type.base)

            Notifications.notify_entity(:entity => mention.entity, :post_id => post.id)
          end
        end

        post
      end

      def self.public_attributes
        [:app_name, :app_url, :entity, :type, :licenses, :content, :published_at]
      end

      def self.write_attributes
        public_attributes + [:following_id, :original, :public, :mentions, :views]
      end

      def can_notify?(app_or_follow)
        return true if public && original
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
        attributes[:version] = latest_version(:fields => [:version]).version
        attributes[:app] = { :url => attributes.delete(:app_url), :name => attributes.delete(:app_name) }

        attributes[:mentions] = mentions.map do |mention|
          h = { :entity => mention.entity }
          h[:post] = mention.mentioned_post_id if mention.mentioned_post_id
          h
        end

        Array(options[:exclude]).each { |k| attributes.delete(k) if k }
        attributes
      end
    end
  end
end
