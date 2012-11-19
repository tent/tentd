module TentD
  module Model
    class PostAttachment < Sequel::Model(:post_attachments)
      many_to_one :post
      many_to_one :post_version
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
#
#       def as_json(options = {})
#         super({ :only => [:type, :category, :name, :size] }.merge(options))
#       end
#     end
#   end
# end
