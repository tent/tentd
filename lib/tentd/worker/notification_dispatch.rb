module TentD
  module Worker

    class NotificationDispatch
      include Sidekiq::Worker

      def perform(post_id)
        # - when public
        #   - lookup matching subscriptions / relationships
        #   - lookup or create relationships with mentioned entities
        #   - queue delivery to these relationships
        # - when private
        #   - lookup subscriptions / relationships for entities in permissions.entities or belong to a group in permissions.groups
        #   - lookup or create relationships for mentioned entities which are also in permissions.entities or belong to a group in permissions.groups

        return unless post = Model::Post.where(:id => post_id).first
        return unless post.deliverable?

        mentioned_entities = post.mentions.to_a.map { |m| m['entity'] }.compact

        unless post.public
          mentioned_entities = post.permissions_entities.to_a & mentioned_entities

          # TODO: permissions.groups
        end

        # TODO: subscriptions

        # TODO: relationship lookup / create

        return if mentioned_entities.empty?

        mentioned_entities.each do |entity|
          NotificationDeliverer.perform_async(post_id, entity)
        end
      end
    end

  end
end
