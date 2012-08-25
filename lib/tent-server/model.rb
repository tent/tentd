require 'data_mapper'
require 'tent-server/data_mapper_array_property'

module TentServer
  module Model
    autoload :Post, 'tent-server/model/post'
    autoload :Follow, 'tent-server/model/follow'
    autoload :App, 'tent-server/model/app'
    autoload :AppAuthorization, 'tent-server/model/app_authorization'
    autoload :NotificationSubscription, 'tent-server/model/notification_subscription'
    autoload :ProfileInfo, 'tent-server/model/profile_info'
  end
end
