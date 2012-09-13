module TentD
  module Model
    class Mention
      include DataMapper::Resource

      storage_names[:default] = "mentions"

      property :id, Serial
      property :entity, Text, :lazy => false, :required => true
      property :mentioned_post_id, String

      belongs_to :post, 'TentD::Model::Post', :required => true
    end
  end
end
