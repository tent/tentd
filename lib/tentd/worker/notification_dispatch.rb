module TentD
  module Worker

    class NotificationDispatch
      include Sidekiq::Worker

      def perform(post_id)
      end
    end

  end
end
