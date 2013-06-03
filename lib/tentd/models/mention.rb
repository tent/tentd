module TentD
  module Model

    class Mention < Sequel::Model(TentD.database[:mentions])
      def self.link_posts(source_post, target_post)
        source_post.mentions ||= []
        source_post.mentions << { "entity" => target_post.entity, "post" => target_post.public_id }
        source_post.save_version

        create(
          :user_id => source_post.user_id,
          :post_id => source_post.id,
          :entity_id => target_post.entity_id,
          :post => target_post.public_id
        )

        true
      end
    end

  end
end
