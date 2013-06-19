module TentD
  module Model

    class Mention < Sequel::Model(TentD.database[:mentions])
      plugin :paranoia if Model.soft_delete

      def self.link_posts(source_post, target_post, options = {})
        source_post.mentions ||= []
        source_post.mentions << { "entity" => target_post.entity, "type" => target_post.type, "post" => target_post.public_id }
        if options[:save_version]
          source_post.save_version
        else
          source_post.version = TentD::Utils.hex_digest(source_post.canonical_json)
          source_post.save
        end

        create(
          :user_id => source_post.user_id,
          :post_id => source_post.id,
          :entity_id => target_post.entity_id,
          :entity => target_post.entity,
          :type_id => target_post.type_id,
          :type => target_post.type,
          :post => target_post.public_id
        )

        true
      end
    end

  end
end
