module TentD
  module Model
    class NotificationSubscription
      include DataMapper::Resource

      storage_names[:default] = 'notification_subscriptions'

      property :id, Serial
      property :type, String
      property :view, String, :default => 'full'
      property :created_at, DateTime
      property :updated_at, DateTime

      belongs_to :app_authorization, 'TentD::Model::AppAuthorization', :required => false
      belongs_to :follower, 'TentD::Model::Follower', :required => false

      before :save, :extract_view

      def version
        TentVersion.from_uri(type)
      end

      private

      def extract_view
        self.view = (type.to_s.match(/#([^\/]+)\Z/) || [])[1]
      end
    end
  end
end
