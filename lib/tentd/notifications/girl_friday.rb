require 'tentd/notifications'
require 'girl_friday'

module TentD
  class Notifications
    def self.queue_job(job, msg)
      const_get(job.to_s.upcase+'_QUEUE').push(msg)
    end

    TRIGGER_QUEUE = GirlFriday::WorkQueue.new(:notification_trigger) do |msg|
      Model::NotificationSubscription.notify_all(msg[:type], msg[:post_id])
    end

    NOTIFY_QUEUE = GirlFriday::WorkQueue.new(:notification) do |msg|
      Model::NotificationSubscription.first(:id => msg[:subscription_id]).notify_about(msg[:post_id])
    end

    NOTIFY_ENTITY_QUEUE = GirlFriday::WorkQueue.new(:notification) do |msg|
      Model::NotificationSubscription.notify_entity(msg[:entity], msg[:post_id])
    end
  end
end
