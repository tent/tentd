module TentD
  class Notifications
    # current job types
    #   - trigger
    #   - notify
    #   - notify_entity
    #   - update_following_profile
    #   - profile_info_update
    def self.method_missing(*args)
      send(:queue_job, *args)
    end
  end
end
