module TentD
  module Model
    class NotificationSubscription
      include DataMapper::Resource

      storage_names[:default] = 'notification_subscriptions'

      property :id, Serial
      property :type, String
      property :view, String, :default => lambda { |m,p| 'full' unless m.type == 'all' }
      property :created_at, DateTime
      property :updated_at, DateTime

      belongs_to :app_authorization, 'TentD::Model::AppAuthorization', :required => false
      belongs_to :follower, 'TentD::Model::Follower', :required => false

      before :save, :extract_view

      def version
        TentVersion.from_uri(type)
      end

      def subject
        app_authorization || follower
      end

      def self.notify_all(type, post_id)
        all(:type => [type, 'all'], :fields => [:id, :app_authorization_id, :follower_id]).each do |subscription|
          next unless Post.get(post_id, :fields => [:id, :original, :public]).can_notify?(subscription.subject)
          Notifications::NOTIFY_QUEUE << { :subscription_id => subscription.id, :post_id => post_id }
        end
      end

      def notify_about(post_id)
        post = Post.get(post_id)
        client = TentClient.new(nil, subject.auth_details)
        permissions = subject.respond_to?(:scopes) && subject.scopes.include?(:read_permissions)
        client.post.create(post.to_json(:app => !!app_authorization, :permissions => permissions), :url => subject.notification_url)
      end

      private

      def extract_view
        self.type, self.view = type.split('#') if type =~ /#/
      end
    end
  end
end
