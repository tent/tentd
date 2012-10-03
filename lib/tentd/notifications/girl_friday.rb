require 'tentd/notifications'
require 'girl_friday'

module TentD
  class Notifications
    def self.queue_job(job, msg)
      const_get(job.to_s.upcase+'_QUEUE').push(msg)
    end

    TRIGGER_QUEUE = GirlFriday::WorkQueue.new(:trigger) do |msg|
      Model::NotificationSubscription.notify_all(msg[:type], msg[:post_id])
    end

    NOTIFY_QUEUE = GirlFriday::WorkQueue.new(:notify) do |msg|
      Model::NotificationSubscription.notify(msg[:subscription_id], msg[:post_id])
    end

    NOTIFY_ENTITY_QUEUE = GirlFriday::WorkQueue.new(:notify_entity) do |msg|
      Model::NotificationSubscription.notify_entity(msg[:entity], msg[:post_id])
    end

    UPDATE_FOLLOWING_PROFILE_QUEUE = GirlFriday::WorkQueue.new(:update_following_profile) do |msg|
      Model::Following.update_profile(msg[:following_id])
    end

    PROFILE_INFO_UPDATE_QUEUE = GirlFriday::WorkQueue.new(:profile_info_update) do |msg|
      Model::ProfileInfo.create_update_post(msg[:profile_info_id])
    end
  end
end
