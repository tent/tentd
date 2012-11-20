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

# module TentD
#   module Model
#     class PostAttachment
#       include DataMapper::Resource
#
#       storage_names[:default] = "post_attachments"
#
#       property :id, Serial
#       property :type, Text, :required => true, :lazy => false
#       property :category, Text, :required => true, :lazy => false
#       property :name, Text, :required => true, :lazy => false
#       property :data, Text, :required => true, :auto_validation => false
#       property :size, Integer, :required => true
#       timestamps :at
#
#       belongs_to :post, 'TentD::Model::Post', :required => false
#       has n, :post_versions, 'TentD::Model::PostVersion', :through => Resource
#     end
#   end
# end
