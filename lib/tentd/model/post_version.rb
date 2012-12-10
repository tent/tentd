module TentD
  module Model
    class PostVersion < Sequel::Model(:post_versions)
      include Serializable
      include TypeProperties
      include Permissible
      include PermissiblePostVersion

      plugin :paranoia
      plugin :serialization
      serialize_attributes :pg_array, :licenses
      serialize_attributes :json, :content, :views

      one_to_many :permissions, :primary_key => :post_id, :key => :post_id
      many_to_many :attachments, :class => 'TentD::Model::PostAttachment', :join_table => :post_versions_attachments, :left_key => :post_version_id, :right_key => :post_attachment_id
      many_to_many :mentions, :join_table => :post_versions_mentions, :left_key => :post_version_id, :right_key => :mention_id

      many_to_one :post
      many_to_one :app
      many_to_one :following

      def before_create
        self.user_id ||= User.current.id
      end

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

        attributes[:permissions] = post_attrs[:permissions]

        Array(options[:exclude]).each { |k| attributes.delete(k) if k }
        attributes
      end
    end
  end
end
