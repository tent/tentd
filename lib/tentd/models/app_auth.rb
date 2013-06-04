module TentD
  module Model

    class AppAuth
      def self.create(current_user, app_post, post_types, scopes = [])

        type = Type.first_or_create("https://tent.io/types/app-auth/v0#")
        published_at_timestamp = Utils.timestamp

        post_attrs = {
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_fragment_id => type.fragment ? type.id : nil,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp,

          :content => {
            :post_types => post_types,
            :scopes => scopes
          },

          :mentions => [
            { "entity" => current_user.entity, "type" => app_post.type, "post" => app_post.public_id }
          ]
        }

        post = Post.create(post_attrs)
        credentials_post = Credentials.generate(current_user, post, :bidirectional_mention => true)

        Mention.create(
          :user_id => current_user.id,
          :post_id => post.id,
          :entity_id => current_user.entity_id,
          :post => app_post.public_id
        )

        Mention.link_posts(app_post, post)

        post
      end
    end

  end
end
