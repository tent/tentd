module TentD
  module Model
    class User < Sequel::Model(:users)
      plugin :paranoia

      one_to_many :posts
      one_to_many :post_versions
      one_to_many :apps
      one_to_many :followings
      one_to_many :followers
      one_to_many :groups
      one_to_many :profile_infos, :class => ProfileInfo
      one_to_many :notification_subscriptions

      def self.first_or_create
        first || create
      end

      def self.current=(u)
        Thread.current[:user] = u
      end

      def self.current
        Thread.current[:user]
      end

      def profile_entity
        info = profile_infos_dataset.where(
          :type_base => ProfileInfo::TENT_PROFILE_TYPE.base,
          :type_version => ProfileInfo::TENT_PROFILE_TYPE.version.to_s
        ).order(:type_version.desc).first
        info.content['entity'] if info
      end
    end
  end
end
