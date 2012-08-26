module TentServer
  module Model
    class ProfileInfo
      include DataMapper::Resource

      storage_names[:default] = 'profile_info'

      property :entity, URI, :key => true
      property :type, URI, :key => true
      property :content, Json, :default => {}

      class << self
        def build_for_entity(entity_hostname)
          all(:entity => URI("https://#{entity_hostname}")).map do |info|
            { :type => info.type }.merge(info.content)
          end
        end
      end
    end
  end
end
