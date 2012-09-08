module TentD
  module Model
    class PostAttachment
      include DataMapper::Resource
      include TypeProperties

      storage_names[:default] = "post_attachments"

      property :id, Serial
      property :category, String
      property :name, String
      property :data, Text
      property :size, Integer
      timestamps :at

      belongs_to :post, 'TentD::Model::Post'

      def as_json(options = {})
        super({ :exclude => [:id, :data, :post_id, :created_at, :updated_at] }.merge(options))
      end
    end
  end
end
