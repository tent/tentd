module TentD
  module Model

    class User < Sequel::Model(TentD.database[:users])
      plugin :serialization
      serialize_attributes :json, :server_credentials

      def self.create(attrs)
        entity = Entity.first_or_create(attrs[:entity])
        user = super(attrs.merge(
          :entity_id => entity.id,
          :server_credentials => {
            :id => TentD::Utils.random_id,
            :hawk_key => TentD::Utils.hawk_key,
            :hawk_algorithm => TentD::Utils.hawk_algorithm
          }
        ))
        user.create_meta_post
        user
      end

      def self.first_or_create(entity_uri)
        first(:entity => entity_uri) || create(:entity => entity_uri)
      end

      def create_meta_post
        type, base_type = Type.find_or_create("https://tent.io/types/meta/v0#")
        published_at_timestamp = (Time.now.to_f * 1000).to_i

        meta_post = Post.create(
          :user_id => self.id,
          :entity_id => self.entity_id,
          :entity => self.entity,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp,

          :content => {
            "entity" => self.entity,
            "servers" => [
              {
                "version" => "0.3",
                "urls" => {
                  "oauth_auth" => "#{self.entity}/oauth/authorize",
                  "oauth_token" => "#{self.entity}/oauth/token",
                  "posts_feed" => "#{self.entity}/posts",
                  "new_post" => "#{self.entity}/posts",
                  "post" => "#{self.entity}/posts/{entity}/{post}",
                  "post_attachment" => "#{self.entity}/posts/{entity}/{post}/attachments/{name}?version={version}",
                  "attachment" => "#{self.entity}/attachments/{entity}/{digest}",
                  "batch" => "#{self.entity}/batch",
                  "server_info" => "#{self.entity}/server"
                },
                "preference" => 0
              }
            ]
          }
        )

        self.update(:meta_post_id => meta_post.id)
        meta_post
      end

      def meta_post
        @meta_post ||= Post.first(:id => self.meta_post_id)
      end

      def preferred_server
        meta_post.content['servers'].sort_by { |server| server['preference'] }.first
      end
    end

  end
end
