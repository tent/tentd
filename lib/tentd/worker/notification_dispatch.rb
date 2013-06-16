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

        # Lookup all subscriptions linked to a relationship
        # where the type matches post.type
        # and someone other than us created the subscription
        subscriptions = Model::Subscription.where(
          :user_id => post.user_id
        ).where(
          Sequel.|({ :type_id => [post.type_id, post.type_base_id] }, { :type => 'all' })
        ).where(
          Sequel.~(:subscriber_entity_id => post.entity_id)
        ).qualify.join(:relationships, :relationships__entity_id => :subscriptions__subscriber_entity_id)

        logger.info "#{subscriptions.sql}"

        subscriptions = subscriptions.all.to_a

        logger.info "Found #{subscriptions.size} subscriptions for #{post_id}"

        # get rid of duplicates
        subscriptions.uniq! { |s| s.relationship_id }

        # queue delivery for each subscription
        subscriptions.each do |subscription|
          NotificationDeliverer.perform_async(post_id, subscription.entity, subscription.entity_id)
        end

        # exclude entities matching a subscription
        mentioned_entities -= subscriptions.map(&:entity)

        # don't attempt to deliver notification to ourself
        mentioned_entities -= [post.entity]

        # TODO: create relationship if none exists

        # queue delivery for each mentioned entity
        mentioned_entities.each do |entity|
          NotificationDeliverer.perform_async(post_id, entity)
        end
      end
    end

  end
end
