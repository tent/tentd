module TentD
  module Model
    class NotificationSubscription
      include DataMapper::Resource
      include TypeProperties
      include UserScoped

      storage_names[:default] = 'notification_subscriptions'

      property :id, Serial
      property :created_at, DateTime
      property :updated_at, DateTime

      belongs_to :app_authorization, 'TentD::Model::AppAuthorization', :required => false
      belongs_to :follower, 'TentD::Model::Follower', :required => false

      def subject
        app_authorization || follower
      end

      def self.notify_all(type, post_id)
        all(:type_base => [type.base, 'all'], :fields => [:id, :app_authorization_id, :follower_id]).each do |subscription|
          next unless Post.first(:id => post_id, :fields => [:id, :original, :public]).can_notify?(subscription.subject)
          Notifications::NOTIFY_QUEUE << { :subscription_id => subscription.id, :post_id => post_id }
        end
      end

      def self.notify_entity(entity, post_id)
        post = Post.first(:id => post_id)
        return if post.entity == entity
        if follow = Follower.first(:entity => entity) || Following.first(:entity => entity)
          return unless post.can_notify?(follow)
          server_urls = API::CoreProfileData.new(follow.profile).servers
          client = TentClient.new(server_urls, follow.auth_details)
        else
          return unless post.public
          client = TentClient.new
          profile, server_url = client.discover(entity).get_profile
          server_urls = API::CoreProfileData.new(profile).servers
          client = TentClient.new(server_urls)
        end
        client.post.create(post.as_json)
      end

      def notify_about(post_id)
        post = Post.first(:id => post_id)
        client = TentClient.new(nil, subject.auth_details)
        permissions = subject.respond_to?(:scopes) && subject.scopes.include?(:read_permissions)
        client.post.create(post.as_json(:app => !!app_authorization, :permissions => permissions), :url => subject.notification_url)
      rescue Faraday::Error::ConnectionFailed
      end
    end
  end
end
