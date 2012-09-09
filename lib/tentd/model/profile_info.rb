require 'hashie'

module TentD
  module Model
    class ProfileInfo
      include DataMapper::Resource
      include TypeProperties

      TENT_PROFILE_TYPE_URI = 'https://tent.io/types/info/core/v0.1.0'
      TENT_PROFILE_TYPE = TentType.new(TENT_PROFILE_TYPE_URI)

      self.raise_on_save_failure = true

      storage_names[:default] = 'profile_info'

      property :id, Serial
      property :public, Boolean, :default => false
      property :content, Json, :default => {}, :lazy => false
      property :created_at, DateTime
      property :updated_at, DateTime

      def self.tent_info(entity_url)
        first(:type => TENT_PROFILE_TYPE.uri, :order => :type_version.desc)
      end

      def self.get_profile(authorized_scopes = [], current_auth = nil)
        h = if (authorized_scopes.include?(:read_profile) || authorized_scopes.include?(:write_profile)) && current_auth.respond_to?(:profile_info_types)
          current_auth.profile_info_types.include?('all') ? all : all(:type => current_auth.profile_info_types.map { |t| TentType.new(t).uri }) + all(:public => true)
        else
          all(:public => true)
        end.inject({}) do |memo, info|
          memo["#{info.type}/v#{info.type_version}"] = info.content
          memo
        end
        h
      end

      def self.update_profile(type, data)
        type = TentType.new(type)
        if (infos = all(:type => type.uri)) && (info = infos.pop)
          infos.destroy
          info.update(:content => data)
        else
          info = create(:type => type, :public => data.delete(:public), :content => data)
        end
      end
    end
  end
end
