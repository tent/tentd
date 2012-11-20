module TentD
  module Model
    class PostAttachment < Sequel::Model(:post_attachments)
      include Serializable

      many_to_one :post
      many_to_one :post_version

      def before_create
        self.created_at = self.updated_at = Time.now
        super
      end

      def before_update
        self.updated_at = Time.now
        super
      end

      def self.public_attributes
        [:type, :category, :name, :size]
      end

      def as_json(options = {})
        super
      end
    end
  end
end
