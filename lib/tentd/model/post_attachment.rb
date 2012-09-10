module TentD
  module Model
    class PostAttachment
      include DataMapper::Resource

      storage_names[:default] = "post_attachments"

      property :id, Serial
      property :type, Text, :required => true, :lazy => false
      property :category, Text, :required => true, :lazy => false
      property :name, Text, :required => true, :lazy => false
      property :data, Text, :required => true
      property :size, Integer, :required => true
      timestamps :at

      belongs_to :post, 'TentD::Model::Post'

      def as_json(options = {})
        super({ :exclude => [:id, :data, :post_id, :created_at, :updated_at] }.merge(options))
      end
    end
  end
end
