module TentD
  module Worker

    class NotificationDeliverer
      include Sidekiq::Worker

      sidekiq_options :retry => 10

      DeliveryFailure = Class.new(StandardError)

      def perform(post_id, entity)
        return unless post = Model::Post.where(:id => post_id).first

        # only deliver relationship posts for now
        return unless post.type == %(https://tent.io/types/relationship/v0#)
        return unless mention = post.mentions.to_a.find { |m| m['entity'] == entity && m['type'] == %(https://tent.io/types/relationship/v0#initial) }

        entity_id = Model::Entity.first_or_create(entity).id
        return unless relationship = Model::Relationship.where(:user_id => post.user_id, :entity_id => entity_id).first

        client = TentClient.new(entity,
          :credentials => Utils::Hash.symbolize_keys(relationship.remote_credentials),
          :server_meta => Utils::Hash.stringify_keys(relationship.meta_post.as_json)
        )

        current_user = Model::User.where(:id => post.user_id).first

        res = client.post.update(post.entity, post.public_id, post.as_json, {}, :notification => true)

        unless res.status == 200
          # TODO: create/update delivery failure post

          # raise DeliveryFailure.new("Failed deliver post(id: #{post.id})!")
        end
      end

      def retries_exhausted(post_id, entity)
        # TODO: update delivery failure post
        # TODO: if it's a relationship post, delete the relationship
      end
    end

  end
end
