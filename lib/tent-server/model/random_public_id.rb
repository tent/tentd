module TentServer
  module Model
    module RandomPublicId
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          property :public_id, String, :required => true, :unique => true, :default => lambda { |*args| random_id }
          self.raise_on_save_failure = true
        end
      end

      module ClassMethods
        def random_id
          rand(36 ** 8 ).to_s(36)
        end
      end

      private

      # catch unique public_id validation and generate a new one
      def assert_save_successful(*args)
        super
      rescue DataMapper::SaveFailureError
        if errors[:public_id].any?
          self.public_id = self.class.random_id
          save
        else
          raise
        end
      end

      # catch db unique constraint on public_id and generate a new one
      def _persist
        super
      rescue DataObjects::IntegrityError
        valid?
        if errors[:public_id].any?
          self.public_id = self.class.random_id
          save
        else
          raise
        end
      end
    end
  end
end
