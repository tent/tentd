module TentServer
  module Model
    class Group
      include DataMapper::Resource
      extend RandomPublicUid::ClassMethods

      self.raise_on_save_failure = true

      storage_names[:default] = "groups"

      property :id, String, :key => true, :unique => true, :default => lambda { |*args| random_uid }
      property :name, String
      property :created_at, DateTime
      property :updated_at, DateTime

      has n, :permissions, 'TentServer::Model::Permission', :constraint => :destroy

      private

      # catch unique id validation and generate a new one
      def assert_save_successful(*args)
        super
      rescue DataMapper::SaveFailureError => e
        if errors[:id].any?
          self.id = self.class.random_uid
          save
        else
          raise e
        end
      end

      # catch db unique constraint on id and generate a new one
      def _persist
        super
      rescue DataObjects::IntegrityError
        valid?
        if errors[:id].any?
          self.id = self.class.random_uid
          save
        else
          raise
        end
      end
    end
  end
end
