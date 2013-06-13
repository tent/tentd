module TentD
  module Model

    class Relationship < Sequel::Model(TentD.database[:relationships])
      def self.create_initial(current_user, target_entity)
        type, base_type = Type.find_or_create("https://tent.io/types/relationship/v0#initial")
        published_at_timestamp = TentD::Utils.timestamp

        post = Post.create(
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp,

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
    end

  end
end
