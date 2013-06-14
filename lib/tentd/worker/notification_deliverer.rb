module TentD
  module Worker

    class NotificationDeliverer
      include Sidekiq::Worker

      def perform(post_id, relationship_id)
      end
    end

  end
end
