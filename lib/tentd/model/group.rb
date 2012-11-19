module TentD
  module Model
    class Group < Sequel::Model(:groups)
      include RandomPublicId
      include Serializable

      one_to_many :permissions

      def before_create
        self.public_id ||= random_id
        self.user_id ||= User.current.id
        super
      end

      def self.public_attributes
        [:name]
      end
    end
  end
end
