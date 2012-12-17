require 'tentd/notifications'
require 'sidekiq'

module TentD
  class Notifications
    def self.queue_job(job, msg)
      const_get(job.to_s.split('_').map(&:capitalize).push('Worker').join).perform_async(msg)
    end

    class TriggerWorker
      include Sidekiq::Worker
      sidekiq_options :queue => 'entity'

      def perform(msg)
        Model::NotificationSubscription.notify_all(msg['type'], msg['post_id'])
      end
    end

    class NotifyWorker
      include Sidekiq::Worker
      sidekiq_options :retry => 5, :backtrace => 0

      def perform(msg)
        Model::NotificationSubscription.notify(msg['subscription_id'], msg['post_id'])
      end
    end

    class NotifyEntityWorker
      include Sidekiq::Worker
      sidekiq_options :retry => 5, :backtrace => 0, :queue => 'entity'

      def perform(msg)
        Model::NotificationSubscription.notify_entity(msg['entity'], msg['post_id'])
      end
    end

    class UpdateFollowingProfileWorker
      include Sidekiq::Worker
      sidekiq_options :queue => 'maintenance'

      def perform(msg)
        Model::Following.update_profile(msg['following_id'])
      end
    end

    class UpdateFollowerEntityWorker
      include Sidekiq::Worker
      sidekiq_options :queue => 'maintenance'

      def perform(msg)
        Model::Follower.update_entity(msg['follower_id'])
      end
    end

    class ProfileInfoUpdateWorker
      include Sidekiq::Worker
      sidekiq_options :queue => 'maintenance'

      def perform(msg)
        Model::ProfileInfo.create_update_post(msg['profile_info_id'], :entity_changed => msg['entity_changed'], :old_entity => msg['old_entity'])
      end
    end

    class PropagateEntityWorker
      include Sidekiq::Worker
      sidekiq_options :queue => 'maintenance'

      def perform(msg)
        Model::Post.propagate_entity(msg['user_id'], msg['entity'], msg['old_entity'])
      end
    end
  end
end
