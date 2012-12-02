require 'jdbc/postgres' if RUBY_ENGINE == 'jruby'

require 'sequel'
require 'sequel/plugins/serialization'
require 'tentd/sequel/plugins/paranoia'

module TentD
  module Model
    require 'tentd/model/pg_array'
    require 'tentd/model/json_column'

    Sequel::Plugins::Serialization.register_format(:pg_array, PGArray::Serialize, PGArray::Deserialize)
    Sequel::Plugins::Serialization.register_format(:json, JsonColumn::Serialize, JsonColumn::Deserialize)

    require 'tentd/model/permissible'
    require 'tentd/model/permissible_post'
    require 'tentd/model/permissible_profile_info'
    require 'tentd/model/serializable'
    require 'tentd/model/random_public_id'
    require 'tentd/model/type_properties'
    require 'tentd/model/mention'
    require 'tentd/model/post'
    require 'tentd/model/post_version'
    require 'tentd/model/post_attachment'
    require 'tentd/model/follower'
    require 'tentd/model/following'
    require 'tentd/model/app'
    require 'tentd/model/app_authorization'
    require 'tentd/model/notification_subscription'
    require 'tentd/model/profile_info'
    require 'tentd/model/profile_info_version'
    require 'tentd/model/group'
    require 'tentd/model/permission'
    require 'tentd/model/user'
  end
end
