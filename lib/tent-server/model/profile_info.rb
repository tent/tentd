require 'hashie'

module TentServer
  module Model
    class ProfileInfo
      include DataMapper::Resource

      TENT_PROFILE_TYPE_URI = 'https://tent.io/types/info/core/v0.1.0'

      self.raise_on_save_failure = true

      storage_names[:default] = 'profile_info'

      property :id, Serial
      property :public, Boolean, :default => false
      property :entity, URI
      property :type, URI
      property :content, Json, :default => {}, :lazy => false
      property :created_at, DateTime
      property :updated_at, DateTime

      def self.tent_info(entity_url)
        first(:entity => entity_url, :type => TENT_PROFILE_TYPE_URI)
      end

      def self.build_for_entity(entity, authorized_scopes = [], current_auth = nil)
        conditions = { :entity => URI(entity) }
        if (authorized_scopes.include?(:read_profile) || authorized_scopes.include?(:write_profile)) && current_auth.respond_to?(:profile_info_types)
          conditions[:type] = current_auth.profile_info_types.to_a
          conditions.delete(:type) if conditions[:type].first.to_s == 'all'
        else
          conditions[:public] = true
        end
        all(conditions).inject({}) do |memo, info|
          memo[info.type.to_s] = info.content
          memo
        end
      end

      def self.update_profile(entity, type, data)
        if (infos = all(:entity => entity, :type => type)) && (info = infos.pop)
          infos.destroy
          info.update(:content => data)
        else
          info = create(:entity => entity, :type => type, :content => data)
        end
      end
    end
  end
end
