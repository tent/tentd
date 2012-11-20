module TentD
  module Model
    class Group < Sequel::Model(:groups)
      include RandomPublicId
      include Serializable

      one_to_many :permissions

      def before_create
        self.public_id ||= random_id
        self.user_id ||= User.current.id
        self.created_at = Time.now
        super
      end

      def before_save
        self.updated_at = Time.now
        super
      end

      def self.public_attributes
        [:name]
      end
    end
  end
end
