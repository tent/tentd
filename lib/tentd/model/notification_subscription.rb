module TentD
  module Model
    class NotificationSubscription
      NotificationError = Class.new(StandardError)

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
        post = Post.first(:id => post_id, :fields => [:id, :original, :public])
        return unless post
        if post.original && post.public
          post.user.notification_subscriptions.all(:type_base => [TentType.new(type).base, 'all'],
                                                   :fields => [:id, :app_authorization_id, :follower_id]).each do |subscription|
            next unless post.can_notify?(subscription.subject)
            Notifications.notify(:subscription_id => subscription.id, :post_id => post_id, :view => subscription.type_view)
          end
        elsif !post.original
          post.user.notification_subscriptions.all(:type_base => [TentType.new(type).base, 'all'],
                                                   :fields => [:id, :app_authorization_id, :follower_id], :app_id.not => nil).each do |subscription|
            next unless post.can_notify?(subscription.subject)
            Notifications.notify(:subscription_id => subscription.id, :post_id => post_id, :view => subscription.type_view)
          end
        else
          post.permissions.all(:follower_access_id.not => nil).follower_access.notification_subscriptions.all(:type_base => [TentType.new(type).base, 'all'],
                                                   :fields => [:id, :app_authorization_id, :follower_id]).each do |subscription|
            next unless post.can_notify?(subscription.subject)
            Notifications.notify(:subscription_id => subscription.id, :post_id => post_id, :view => subscription.type_view)
          end
        end
      end

      def self.notify_entity(entity, post_id, view='full')
        post = Post.first(:id => post_id)
        return if post.entity == entity
        return unless post
        entity = 'https://' + entity if !entity.match(%r{\Ahttp})
        if follow = post.user.followers.first(:entity => entity) || post.user.followings.first(:entity => entity)
          return unless post.can_notify?(follow)
          client = TentClient.new(follow.notification_servers, follow.auth_details.merge(:faraday_adapter => TentD.faraday_adapter))
          path = follow.notification_path
        else
          return unless post.public
          profile, server_url = TentClient.new(nil, :faraday_adapter => TentD.faraday_adapter).discover(entity).get_profile
          server_urls = API::CoreProfileData.new(profile).servers
          client = TentClient.new(server_urls, :faraday_adapter => TentD.faraday_adapter)
          path = 'posts'
        end
        res = client.post.create(post.as_json(:view => view), :url => path)
        raise NotificationError unless (200...300).include?(res.status)
        res
      end

      def notify_about(post_id, view='full')
        post = Post.first(:id => post_id)
        return unless post
        client = TentClient.new(subject.notification_servers, subject.auth_details.merge(:faraday_adapter => TentD.faraday_adapter))
        permissions = subject.respond_to?(:scopes) && subject.scopes.include?(:read_permissions)
        res = client.post.create(post.as_json(:app => !!app_authorization, :permissions => permissions, :view => view), :url => subject.notification_path)
        raise NotificationError unless (200...300).include?(res.status)
        res
      rescue Faraday::Error::ConnectionFailed
        raise NotificationError
      end
    end
  end
end
