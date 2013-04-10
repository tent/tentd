module TentD
  module Model

    class Credentials < Sequel::Model(TentD.database[:credentials])
      def self.generate(current_user, target_post)
        type = Type.first_or_create("https://tent.io/types/credentials/v0")
        published_at_timestamp = (Time.now.to_f * 1000).to_i

        post = Post.create(
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_fragment_id => type.fragment ? type.id : nil,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,

          :content => {
            :mac_key => TentD::Utils.mac_key,
            :mac_algorithm => TentD::Utils.mac_algorithm
          },

          :mentions => [
            { "entity" => current_user.entity, "post" => target_post.public_id }
          ]
        )

        Mention.create(
          :user_id => current_user.id,
          :post_id => post.id,
          :entity_id => current_user.entity_id,
          :post => target_post.public_id
        )

        post
      end
    end

  end
end
