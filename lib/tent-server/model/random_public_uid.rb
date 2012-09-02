module TentServer
  module Model
    module RandomPublicUid
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          property :public_uid, String, :required => true, :unique => true, :default => lambda { |*args| random_uid }
          self.raise_on_save_failure = true
        end
      end

      module ClassMethods
        def random_uid
          rand(36 ** 8 ).to_s(36)
        end
      end

      private

      # catch unique public_uid validation and generate a new one
      def assert_save_successful(*args)
        super
      rescue DataMapper::SaveFailureError
        if errors[:public_uid].any?
          self.public_uid = self.class.random_uid
          save
        else
          raise
        end
      end

      # catch db unique constraint on public_uid and generate a new one
      def _persist
        super
      rescue DataObjects::IntegrityError
        valid?
        if errors[:public_uid].any?
          self.public_uid = self.class.random_uid
          save
        else
          raise
        end
      end
    end
  end
end
