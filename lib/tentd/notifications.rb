require 'girl_friday'
require 'tentd/notifications'

module TentD
  class Notifications
    def self.trigger(msg)
      queue_job(:trigger, msg)
    end

    def self.notify(msg)
      queue_job(:notify, msg)
    end

    def self.notify_entity(msg)
      queue_job(:notify_entity, msg)
    end
  end
end
