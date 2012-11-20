require 'jdbc/postgres' if RUBY_ENGINE == 'jruby'

require 'sequel'
require 'sequel/plugins/serialization'

module TentD
  module Model
    autoload :PGArray, 'tentd/model/pg_array'
    autoload :JsonColumn, 'tentd/model/json_column'
    autoload :Permissible, 'tentd/model/permissible'
    autoload :PermissiblePost, 'tentd/model/permissible_post'
    autoload :Serializable, 'tentd/model/serializable'
    autoload :RandomPublicId, 'tentd/model/random_public_id'
    autoload :TypeProperties, 'tentd/model/type_properties'
    autoload :Mention, 'tentd/model/mention'
    autoload :Post, 'tentd/model/post'
    autoload :PostVersion, 'tentd/model/post_version'
    autoload :PostAttachment, 'tentd/model/post_attachment'
    autoload :Follower, 'tentd/model/follower'
    autoload :Following, 'tentd/model/following'
    autoload :App, 'tentd/model/app'
    autoload :AppAuthorization, 'tentd/model/app_authorization'
    autoload :NotificationSubscription, 'tentd/model/notification_subscription'
    autoload :ProfileInfo, 'tentd/model/profile_info'
    autoload :Group, 'tentd/model/group'
    autoload :Permission, 'tentd/model/permission'
    autoload :User, 'tentd/model/user'

    Sequel::Plugins::Serialization.register_format(:pg_array, PGArray::Serialize, PGArray::Deserialize)
    Sequel::Plugins::Serialization.register_format(:json, JsonColumn::Serialize, JsonColumn::Deserialize)
  end
end
