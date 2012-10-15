module TentD
  module Model
    class PostVersion
      include DataMapper::Resource
      include Permissible
      include PermissiblePost
      include Serializable
      include TypeProperties
      include UserScoped

      storage_names[:default] = "post_versions"

      belongs_to :post, 'TentD::Model::Post', :required => true
      property :version, Integer, :required => true

      property :id, Serial
      property :entity, Text, :lazy => false
      property :public_id, String, :required => true
      property :public, Boolean, :default => false
      property :licenses, Array, :default => []
      property :content, Json, :default => {}
      property :views, Json, :default => {}
      property :published_at, DateTime, :default => lambda { |*args| Time.now }
      property :received_at, DateTime, :default => lambda { |*args| Time.now }
      property :updated_at, DateTime
      property :deleted_at, ParanoidDateTime
      property :app_name, Text, :lazy => false
      property :app_url, Text, :lazy => false
      property :original, Boolean, :default => false

      has n, :attachments, 'TentD::Model::PostAttachment', :constraint => :destroy
      has n, :mentions, 'TentD::Model::Mention', :constraint => :destroy
      belongs_to :app, 'TentD::Model::App', :required => false
      belongs_to :following, 'TentD::Model::Following', :required => false

      def self.public_attributes
        Post.public_attributes
      end

      def as_json(options = {})
        attributes = super
        post_attrs = post.as_json(options)

        attributes[:type] = type.uri
        attributes[:version] = version
        attributes[:app] = { :url => attributes.delete(:app_url), :name => attributes.delete(:app_name) }

        attributes[:mentions] = mentions.map do |mention|
          h = { :entity => mention.entity }
          h[:post] = mention.mentioned_post_id if mention.mentioned_post_id
          h
        end

        if options[:app]
          attributes[:following_id] = following.public_id if following
        end

        attributes[:permissions] = post_attrs[:permissions]

        Array(options[:exclude]).each { |k| attributes.delete(k) if k }
        attributes
      end
    end
  end
end
