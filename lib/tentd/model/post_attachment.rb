module TentD
  module Model
    class PostAttachment < Sequel::Model(:post_attachments)
      include Serializable

      many_to_one :post
      many_to_many :post_versions, :class => PostVersion, :join_table => :post_versions_attachments, :left_key => :post_attachment_id, :right_key => :post_version_id

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
