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
        Model::NotificationSubscription.notify(msg['subscription_id'], msg['post_id'])
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

    class ProfileInfoUpdateWorker
      include Sidekiq::Worker

      def perform(msg)
        Model::ProfileInfo.create_update_post(msg['profile_info_id'])
      end
    end

    class PropagateEntityWorker
      include Sidekiq::Worker

      def perform(msg)
        Model::Post.propagate_entity(msg['user_id'], msg['entity'], msg['old_entity'])
      end
    end
  end
end
