require 'tentd/notifications'
require 'sidekiq'

module TentD
  class Notifications
    def self.queue_job(job, msg)
      const_get(job.to_s.split('_').map(&:capitalize).push('Worker').join).perform_async(msg)
    end

    class TriggerWorker
      include Sidekiq::Worker

      def perform(msg)
        Model::NotificationSubscription.notify_all(msg['type'], msg['post_id'])
      end
    end

    class NotifyWorker
      include Sidekiq::Worker

      def perform(msg)
        Model::NotificationSubscription.first(:id => msg['subscription_id']).notify_about(msg['post_id'])
      end
    end

    class NotifyEntityWorker
      include Sidekiq::Worker

      def perform(msg)
        Model::NotificationSubscription.notify_entity(msg['entity'], msg['post_id'])
      end
    end

    class UpdateFollowingProfileWorker
      include Sidekiq::Worker

      def perform(msg)
        Model::Following.update_profile(msg['following_id'])
      end
    end
  end
end
