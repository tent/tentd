module TentServer
  module Model
    class Follow
      include DataMapper::Resource

      storage_names[:default] = 'follows'

      property :id, Serial
      property :groups, Array
      property :entity, URI
      property :profile, Json
      property :type, Enum[:following, :follower]
      timestamps :at
    end
  end
end
