require 'hashie'

module TentD
  module Model
    class ProfileInfo < Sequel::Model(:profile_info)
      TENT_PROFILE_TYPE_URI = 'https://tent.io/types/info/core/v0.1.0'
      TENT_PROFILE_TYPE = TentType.new(TENT_PROFILE_TYPE_URI)

      include TypeProperties
      include Permissible

      plugin :paranoia
      plugin :serialization
      serialize_attributes :json, :content

      one_to_many :permissions
      many_to_one :user

      attr_accessor :entity_changed, :old_entity

      def before_create
        self.user_id ||= User.current.id
        self.created_at = Time.now
        super
      end

      def before_save
        self.updated_at = Time.now
        super
      end

      def self.first_or_create(attrs)
        first(attrs) || create(attrs)
      end

      def self.tent_info
        where(
          :type_base => TENT_PROFILE_TYPE.base,
          :type_version => TENT_PROFILE_TYPE.version.to_s,
          :user_id => User.current.id
        ).order(:type_version.desc).first || Hashie::Mash.new
      end

      def self.get_profile(authorized_scopes = [], current_auth = nil)
        h = if (authorized_scopes.include?(:read_profile) || authorized_scopes.include?(:write_profile)) && current_auth.respond_to?(:profile_info_types)
          query = where(:user_id => User.current.id)
          current_auth.profile_info_types.include?('all') ? query.all : query.where({ :type_base => current_auth.profile_info_types.map { |t| TentType.new(t).base }, :public => true }.sql_or).all
        else
          fetch_with_permissions({}, current_auth)
        end.inject({}) do |memo, info|
          memo[info.type.uri] = info.content.merge(:permissions => info.permissions_json(authorized_scopes.include?(:read_permissions)))
          memo
        end
        h
      end

      def self.update_profile(type, data)
        data = Hashie::Mash.new(data) unless data.kind_of?(Hashie::Mash)
        type = TentType.new(type)
        perms = data.delete(:permissions)
        existing_infos = where(:user_id => User.current.id, :type_base => type.base)
        if existing_infos.any? && (info = existing_infos.order(:id.asc).last)
          existing_infos.where(Sequel.~(:id => info.id)).destroy
          info.old_entity = (info.content || {})['entity']
          info.entity_changed = true if type.base == TENT_PROFILE_TYPE.base && data.find { |k,v| k.to_s == 'entity' && v != info.old_entity }
          data['previous_entities'] = (data['previous_entities'] || []).unshift(info.old_entity).uniq if info.entity_changed
          info.type = type
          info.content = data
          info.save
        else
          info = create(:type => type, :content => data)
          info.old_entity = nil
          info.entity_changed = true if type.base == TENT_PROFILE_TYPE.base && (info.content || {})['entity']
        end
        info.assign_permissions(perms)
        if info.entity_changed
          Notifications.propagate_entity('user_id' => TentD::Model::User.current.id, 'entity' => (info.content || {})['entity'], 'old_entity' => info.old_entity) if info.entity_changed
        end
        info
      end

      def self.create_update_post(id, options = {})
        first(:id => id).create_update_post(options)
      end

      def create_update_post(options = {})
        post = Post.create(
          :user_id => user_id,
          :type => 'https://tent.io/types/post/profile/v0.1.0',
          :entity => options[:entity_changed] ? options[:old_entity] : user.profile_entity,
          :original => true,
          :content => {
            :action => 'update',
            :types => [self.type.uri],
          }
        )
        Permission.copy(self, post)
        Notifications.trigger(:type => post.type.uri, :post_id => post.id)

        if options[:entity_changed]
          Mention.select(:id, :entity).qualify.join(
            :posts,
            :mentions__post_id => :posts__id
          ).where(:posts__original => true, :posts__deleted_at => nil).where(Sequel.~(:mentions__entity => user.profile_entity)).each do |mention|
            Notifications.notify_entity(:entity => mention.entity, :post_id => post.id)
          end
        end
      end
    end
  end
end
