module TentD
  module Model

    class AppAuth
      def self.create(current_user, app_post, post_types, scopes = [])

        type, base_type = Type.find_or_create("https://tent.io/types/app-auth/v0#")
        published_at_timestamp = Utils.timestamp

        post_attrs = {
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => published_at_timestamp,
          :version_received_at => published_at_timestamp,
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

        # Update app record
        app = App.first(:post_id => app_post.id)
        app.update(
          :auth_hawk_key => credentials_post.content['hawk_key'],
          :auth_credentials_post_id => credentials_post.id,

          :read_post_types => post_types['read'],
          :read_post_type_ids => Type.find_types(post_types['read']).map(&:id),
          :write_post_types => post_types['write']
        )

        Mention.create(
          :user_id => current_user.id,
          :post_id => post.id,
          :entity_id => post.entity_id,
          :entity => post.entity,
          :type_id => app_post.type_id,
          :type => app_post.type,
          :post => app_post.public_id
        )

        Mention.link_posts(app_post, post)

        post
      end
    end

  end
end
