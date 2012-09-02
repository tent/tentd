module TentServer
  module Model
    class PostAttachment
      include DataMapper::Resource

      property :id, Serial
      property :category, String
      property :type, String
      property :name, String
      property :data, Binary

      belongs_to :post, 'TentServer::Model::Post'
    end
  end
end
