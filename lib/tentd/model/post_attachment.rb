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

      belongs_to :post, 'TentD::Model::Post', :required => false
      belongs_to :post_version, 'TentD::Model::PostVersion', :required => false

      validates_presence_of :post_id, :if => lambda { |m| m.post_version_id.nil? }
      validates_presence_of :post_version_id, :if => lambda { |m| m.post_id.nil? }

      def as_json(options = {})
        super({ :only => [:type, :category, :name, :size] }.merge(options))
      end
    end
  end
end
