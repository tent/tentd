module TentD
  module Model
    class User
      include DataMapper::Resource

      storage_names[:default] = 'users'

      property :id, Serial
      property :created_at, DateTime
      property :updated_at, DateTime
      property :deleted_at, ParanoidDateTime

      has n, :posts, 'TentD::Model::Post'
      has n, :post_versions, 'TentD::Model::PostVersion'
      has n, :apps, 'TentD::Model::App'
      has n, :followings, 'TentD::Model::Following'
      has n, :followers, 'TentD::Model::Follower'
      has n, :groups, 'TentD::Model::Group'
      has n, :profile_infos, 'TentD::Model::ProfileInfo'
      has n, :notification_subscriptions, 'TentD::Model::NotificationSubscription'

      def self.current=(u)
        relationships.each do |relationship|
          relationship.child_model.default_scope(:default).update(:user => u)
        end
        Thread.current[:user] = u
      end

      def self.current
        Thread.current[:user]
      end

      def profile_entity
        info = profile_infos.first(:type_base => ProfileInfo::TENT_PROFILE_TYPE.base, :order => :type_version.desc)
        info.content['entity'] if info
      end
    end
  end
end
