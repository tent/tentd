module TentD
  module Model

    class Relationship < Sequel::Model(TentD.database[:relationships])
      def self.create_initial(current_user, target_entity)
        type = Type.first_or_create("https://tent.io/types/relationship/v0#initial")
        published_at_timestamp = TentD::Utils.timestamp

        post = Post.create(
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_fragment_id => type.fragment ? type.id : nil,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,

          :mentions => [
            { "entity" => target_entity }
          ]
        )

        Mention.create(
          :user_id => current_user.id,
          :post_id => post.id,
          :entity_id => Entity.first_or_create(target_entity).id
        )

        post
      end

      def self.create_from_env(env)
        initiating_post = env['data']
        current_user = env['current_user']
        type = Type.first_or_create("https://tent.io/types/relationship/v0#")
        published_at_timestamp = TentD::Utils.timestamp

        ##
        # Create new relationship post mentioning initiating post
        post = Post.create(
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_fragment_id => type.fragment ? type.id : nil,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,

          :mentions => [
            { "entity" => initiating_post['entity'], "post" => initiating_post['id'] }
          ]
        )

        ##
        # Create new credentials post mentioning new relationship post
        credentials_post = Credentials.generate(current_user, post)

        [post, credentials_post]
      end
    end

  end
end
