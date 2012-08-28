require 'data_mapper'
require 'tent-server/data_mapper_array_property'

module TentServer
  module Model
    require 'tent-server/model/post'
    require 'tent-server/model/follow'
    require 'tent-server/model/app'
    require 'tent-server/model/app_authorization'
    require 'tent-server/model/notification_subscription'
    require 'tent-server/model/profile_info'
    require 'tent-server/model/group'
    require 'tent-server/model/permission'
  end
end

DataMapper.finalize
