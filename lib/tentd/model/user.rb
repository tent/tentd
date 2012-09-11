module TentD
  module Model
    class User
      include DataMapper::Resource

      storage_names[:default] = 'users'

      property :id, Serial

      has n, :posts, 'TentD::Model::Post'
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
    end
  end
end
