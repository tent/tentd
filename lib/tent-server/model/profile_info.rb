module TentServer
  module Model
    class ProfileInfo
      include DataMapper::Resource

      storage_names[:default] = 'profile_info'

      property :id, Serial
      property :type, URI
      property :content, Json
    end
  end
end
