require 'hashie'

module TentD
  module Model
    class ProfileInfo
      include DataMapper::Resource
      include TypeProperties
      include UserScoped
      include Permissible

      TENT_PROFILE_TYPE_URI = 'https://tent.io/types/info/core/v0.1.0'
      TENT_PROFILE_TYPE = TentType.new(TENT_PROFILE_TYPE_URI)

      self.raise_on_save_failure = true

      storage_names[:default] = 'profile_info'

      property :id, Serial
      property :public, Boolean, :default => false
      property :content, Json, :default => {}, :lazy => false
      property :created_at, DateTime
      property :updated_at, DateTime
      property :deleted_at, ParanoidDateTime

      has n, :permissions, 'TentD::Model::Permission'

      attr_accessor :entity_changed

      def self.tent_info
        first(:type_base => TENT_PROFILE_TYPE.base, :order => :type_version.desc) || Hashie::Mash.new
      end

      def self.get_profile(authorized_scopes = [], current_auth = nil)
        h = if (authorized_scopes.include?(:read_profile) || authorized_scopes.include?(:write_profile)) && current_auth.respond_to?(:profile_info_types)
          current_auth.profile_info_types.include?('all') ? all : all(:type_base => current_auth.profile_info_types.map { |t| TentType.new(t).base }) + all(:public => true)
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
        if (infos = all(:type_base => type.base)) && (info = infos.pop)
          infos.to_a.each(&:destroy)
          old_entity = (info.content || {})['entity']
          info.entity_changed = true if type.base == TENT_PROFILE_TYPE.base && data.find { |k,v| k.to_s == 'entity' && v != old_entity }
          data['previous_entities'] = (data['previous_entities'] || []).unshift(old_entity) if info.entity_changed
          info.type = type
          info.content = data
          info.save
        else
          info = create(:type => type, :content => data)
          old_entity = nil
          info.entity_changed = true if type.base == TENT_PROFILE_TYPE.base && (info.content || {})['entity']
        end
        info.assign_permissions(perms)
        if info.entity_changed
          Notifications.propagate_entity('entity' => (info.content || {})['entity'], 'old_entity' => old_entity) if info.entity_changed
        end
        info
      end

      def self.create_update_post(id)
        first(:id => id).create_update_post
      end

      def create_update_post
        post = user.posts.create(
          :type => 'https://tent.io/types/post/profile/v0.1.0',
          :entity => user.profile_entity,
          :original => true,
          :content => {
            :action => 'update',
            :types => [self.type.uri],
          }
        )
        Permission.copy(self, post)
        Notifications.trigger(:type => post.type.uri, :post_id => post.id)
      end
    end
  end
end
