module TentD
  module Model

    class User < Sequel::Model(TentD.database[:users])
      plugin :serialization
      serialize_attributes :json, :server_credentials

      plugin :paranoia if Model.soft_delete

      def self.create(attrs, options = {})
        entity = Entity.first_or_create(attrs[:entity])
        user = super(attrs.merge(
          :entity_id => entity.id,
          :server_credentials => {
            :id => TentD::Utils.random_id,
            :hawk_key => TentD::Utils.hawk_key,
            :hawk_algorithm => TentD::Utils.hawk_algorithm
          }
        ))
        user.create_meta_post(options.delete(:meta_post_attrs) || {})
        user
      end

      def self.first_or_create(entity_uri)
        first(:entity => entity_uri) || create(:entity => entity_uri)
      end

      def create_meta_post(attrs = {})
        type, base_type = Type.find_or_create("https://tent.io/types/meta/v0#")
        published_at_timestamp = Utils.timestamp

        api_root = ENV['API_ROOT'] || self.entity

        Utils::Hash.deep_merge!(attrs, {
          :user_id => self.id,
          :entity_id => self.entity_id,
          :entity => self.entity,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => published_at_timestamp,
          :version_received_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp,

          :content => {
            "entity" => self.entity,
            "servers" => [
              {
                "version" => "0.3",
                "urls" => {
                  "oauth_auth" => "#{api_root}/oauth/authorize",
                  "oauth_token" => "#{api_root}/oauth/token",
                  "posts_feed" => "#{api_root}/posts",
                  "new_post" => "#{api_root}/posts",
                  "post" => "#{api_root}/posts/{entity}/{post}",
                  "post_attachment" => "#{api_root}/posts/{entity}/{post}/attachments/{name}",
                  "attachment" => "#{api_root}/attachments/{entity}/{digest}",
                  "batch" => "#{api_root}/batch",
                  "server_info" => "#{api_root}/server",
                  "discover" => "#{api_root}/discover?entity={entity}"
                },
                "preference" => 0
              }
            ]
          },
          :public => true
        })

        meta_post = Post.create(attrs)

        self.update(:meta_post_id => meta_post.id)
        meta_post
      end

      def update_meta_post_id(meta_post)
        return unless meta_post.entity_id == self.entity_id

        self.update(:meta_post_id => meta_post.id)
        @meta_post = meta_post
      end

      def reload
        super
        reload_meta_post
        self
      end

      def reload_meta_post
        @meta_post = Post.first(:id => self.meta_post_id)
      end

      def meta_post
        @meta_post || reload_meta_post
      end

      def preferred_server
        meta_post.content['servers'].sort_by { |server| server['preference'] }.first
      end
    end

  end
end
