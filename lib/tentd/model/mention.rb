module TentD
  module Model
    class Mention
      include DataMapper::Resource

      storage_names[:default] = "mentions"

      property :id, Serial
      property :entity, Text, :lazy => false, :required => true
      property :mentioned_post_id, String

      belongs_to :post, 'TentD::Model::Post', :required => false
      belongs_to :post_version, 'TentD::Model::PostVersion', :required => false

      validates_presence_of :post_id, :if => lambda { |m| m.post_version_id.nil? }
      validates_presence_of :post_version_id, :if => lambda { |m| m.post_id.nil? }

      after :create do |mention|
        if mention.post
          attrs = mention.attributes
          attrs.delete(:id)
          attrs[:post_version] = mention.post.versions.all(:order => :version.desc, :fields => [:id]).first
          attrs.delete(:post_id)
          Mention.create(attrs)
        end
      end
    end
  end
end
