require 'hashie'

module TentD
  module Model
    class ProfileInfo < Sequel::Model(:profile_info)
      TENT_PROFILE_TYPE_URI = 'https://tent.io/types/info/core/v0.1.0'
      TENT_PROFILE_TYPE = TentType.new(TENT_PROFILE_TYPE_URI)

      include TypeProperties
      include Permissible
      include PermissibleProfileInfo

      plugin :paranoia
      plugin :serialization
      serialize_attributes :json, :content

      one_to_many :permissions
      one_to_many :versions, :class => 'TentD::Model::ProfileInfoVersion'
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

      def after_save
        create_version!
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
          memo[info.type.uri] = info.content.merge(:permissions => info.permissions_json(authorized_scopes.include?(:read_permissions)), :version => info.latest_version(:fields => [:version]).version)
          memo
        end
        h
      end

      def self.get_profile_type(type, params, authorized_scopes = [], current_auth = nil)
        type = TentType.new(type)
        info = if (authorized_scopes.include?(:read_profile) || authorized_scopes.include?(:write_profile)) && current_auth.respond_to?(:profile_info_types)
          query = where(:user_id => User.current.id, :type_base => type.base)
          if params.has_key?(:version)
            query = query.select(:id, :public)
          end
          unless current_auth.profile_info_types.any? { |t| t == 'all' || TentType.new(t).base == type.base }
            query = query.where(:public => true)
          end
          query.first
        else
          fetch_params = { :type_base => type.base, :limit => 1 }
          fetch_params[:_select] = [:id, :public] if params.has_key?(:version)
          fetch_with_permissions(fetch_params, current_auth).first
        end
        return unless info
        if params.has_key?(:version)
          version = ProfileInfoVersion.where(:user_id => User.current.id, :version => params[:version], :profile_info_id => info.id).first
          return unless version
          version.content.merge(
            :permissions => info.permissions_json(authorized_scopes.include?(:read_permissions)),
            :version => version.version
          )
        else
          info.content.merge(
            :permissions => info.permissions_json(authorized_scopes.include?(:read_permissions)),
            :version => info.latest_version(:fields => [:version]).version
          )
        end
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

        Following.select(:id, :entity).where(:user_id => user_id).all.each do |following|
          Notifications.notify_entity(:entity => following.entity, :post_id => post.id)
        end

        if options[:entity_changed]
          Mention.select(:id, :entity).qualify.join(
            :posts,
            :mentions__post_id => :posts__id
          ).where(:posts__original => true, :posts__deleted_at => nil).where(Sequel.~(:mentions__entity => user.profile_entity)).each do |mention|
            Notifications.notify_entity(:entity => mention.entity, :post_id => post.id)
          end
        end
      end

      def latest_version(params = {})
        q = ProfileInfoVersion.where(:profile_info_id => id).order(:version.desc)
        q.select(params.delete(:fields)) if params[:fields]
        q.first
      end

      def create_version!
        latest_version = self.latest_version(:fields => [:version])
        ProfileInfoVersion.create(
          :profile_info_id => id,
          :type => type,
          :version => latest_version ? latest_version.version + 1 : 1,
          :user_id => user_id,
          :public => self.public,
          :content => content
        )
      end
    end
  end
end
