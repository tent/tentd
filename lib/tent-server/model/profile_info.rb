module TentServer
  module Model
    class ProfileInfo
      include DataMapper::Resource

      TENT_PROFILE_TYPE_URI = 'https://tent.io/types/info/core/v0.1.0'

      storage_names[:default] = 'profile_info'

      property :id, Serial
      property :entity, URI
      property :type, URI
      property :content, Json, :default => {}, :lazy => false

      has n, :permissions, 'TentServer::Model::Permission'

      def self.tent_info(entity_url)
        first(:entity => entity_url, :type => TENT_PROFILE_TYPE_URI)
      end

      def self.build_for_entity(entity_hostname)
        all(:entity => URI("https://#{entity_hostname}")).inject({}) do |memo, info|
          memo[info.type.to_s] = info.content
          memo
        end
      end

      def self.update_for_entity(entity_hostname, profile_infos_hash)
        entity_uri = URI("https://#{entity_hostname}")
        profile_infos = profile_infos_hash.inject([]) do |memo, (type_url, content)|
          memo << new(:type => URI(type_url), :entity => entity_uri, :content => content)
          memo
        end
        old_profile_infos = all(:entity => entity_uri).to_a

        profile_infos.each(&:save!)
        old_profile_infos.each(&:destroy)
      end

      def self.update_type_for_entity(entity_hostname, type_url, type_hash)
        entity_uri = URI("https://#{entity_hostname}")
        type_uri = URI(type_url)

        profile_info = new(:type => type_uri, :entity => entity_uri, :content => type_hash)
        old_profile_infos = all(:entity => entity_uri, :type => type_uri).to_a
        profile_info.save!
        old_profile_infos.each(&:destroy)
      end
    end
  end
end
