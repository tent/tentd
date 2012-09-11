require 'jdbc/postgres' if RUBY_ENGINE == 'jruby'
require 'data_mapper'
require 'dm-ar-finders'
require 'tentd/datamapper/array_property'
require 'tentd/datamapper/query'

module TentD
  module Model
    require 'tentd/model/permissible'
    require 'tentd/model/serializable'
    require 'tentd/model/random_public_id'
    require 'tentd/model/type_properties'
    require 'tentd/model/user_scoped'
    require 'tentd/model/post'
    require 'tentd/model/post_attachment'
    require 'tentd/model/follower'
    require 'tentd/model/following'
    require 'tentd/model/app'
    require 'tentd/model/app_authorization'
    require 'tentd/model/notification_subscription'
    require 'tentd/model/profile_info'
    require 'tentd/model/group'
    require 'tentd/model/permission'
    require 'tentd/model/user'
  end
end

DataMapper.finalize
