module TentD
  module Worker

    class NotificationDeliverer
      include Sidekiq::Worker

      sidekiq_options :retry => 10

      DeliveryFailure = Class.new(StandardError)
      RelationshipNotFound = Class.new(DeliveryFailure)

      def perform(post_id, entity, relationship_id=nil)
        unless post = Model::Post.where(:id => post_id).first
          logger.info "#{post_id} deleted"
          return
        end

        unless relationship_id && (relationship = Model::Relationship.where(:id => relationship_id).first)
          entity_id = Model::Entity.first_or_create(entity).id
          relationship = Model::Relationship.where(:user_id => post.user_id, :entity_id => entity_id).first
        end

        unless relationship && relationship.remote_credentials_id
          logger.error "Failed to deliver Post(#{post_id}) to Entity(#{entity}), No viable relationship exists."
          raise RelationshipNotFound.new("No viable Relationship(#{post.user_id}, #{entity_id})")
        end

        client = TentClient.new(entity,
          :credentials => Utils::Hash.symbolize_keys(relationship.remote_credentials),
          :server_meta => Utils::Hash.stringify_keys(relationship.meta_post.as_json)
        )

        current_user = Model::User.where(:id => post.user_id).first

        res = client.post.update(post.entity, post.public_id, post.as_json, {}, :notification => true)

        unless res.status == 200
          # TODO: create/update delivery failure post

          raise DeliveryFailure.new("Failed deliver post(id: #{post.id}) via #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}\nREQUEST_BODY: #{post.as_json.inspect}\n\nRESPONSE_BODY: #{res.body.inspect}")
        end
      end

      def retries_exhausted(post_id, entity)
        # TODO: update delivery failure post
        # TODO: if it's a relationship post, delete the relationship
      end
    end

  end
end
