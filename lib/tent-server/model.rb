require 'data_mapper'
require 'dm-ar-finders'
require 'tent-server/datamapper/array_property'
require 'tent-server/datamapper/binary_string_property'
require 'tent-server/datamapper/query'

module TentServer
  module Model
    require 'tent-server/model/permissible'
    require 'tent-server/model/random_public_id'
    require 'tent-server/model/post'
    require 'tent-server/model/post_attachment'
    require 'tent-server/model/follower'
    require 'tent-server/model/following'
    require 'tent-server/model/app'
    require 'tent-server/model/app_authorization'
    require 'tent-server/model/notification_subscription'
    require 'tent-server/model/profile_info'
    require 'tent-server/model/group'
    require 'tent-server/model/permission'
  end
end

DataMapper.finalize
