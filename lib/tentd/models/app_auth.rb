module TentD
  module Model

    class AppAuth
      def self.create_from_env(env)
        data = env['data']

        app_mention = data['mentions'].to_a.find { |m| TentType.new(m['type']).base == %(https://tent.io/types/app) }
        app_public_id = app_mention['post'] if app_mention

        unless app_public_id
          raise Post::CreateFailure.new("Post must mention an app")
        end

        app_post = Post.where(
          :user_id => env['current_user'].id,
          :public_id => app_public_id
        ).order(Sequel.desc(:received_at)).first

        unless app_public_id
          raise Post::CreateFailure.new("Post must mention an existing app")
        end

        self.create(
          env['current_user'],
          app_post,
          data['content']['types'],
          data['content']['scopes'].to_a
        )
      end

      def self.create(current_user, app_post, types, scopes = [])

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
            :types => types,
            :scopes => scopes
          },

          :mentions => [
            { "entity" => current_user.entity, "type" => app_post.type, "post" => app_post.public_id }
          ]
        }

        post = Post.create(post_attrs)
        credentials_post = Credentials.generate(current_user, post, :bidirectional_mention => true)

        # Ref credentials
        post.refs = [
          { "entity" => current_user.entity, "type" => credentials_post.type, "post" => credentials_post.public_id }
        ]
        post = post.save_version(:public_id => post.public_id)

        # Update app record
        app = App.first(:post_id => app_post.id)
        app.update(
          :auth_post_id => post.id,
          :auth_hawk_key => credentials_post.content['hawk_key'],
          :auth_credentials_post_id => credentials_post.id,

          :read_types => types['read'],
          :read_type_ids => Type.find_types(types['read']).map(&:id),
          :write_types => types['write']
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
