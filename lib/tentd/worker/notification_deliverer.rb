module TentD
  module Worker

    class NotificationDeliverer
      include Sidekiq::Worker

      sidekiq_options :retry => 10

      DeliveryFailure = Class.new(StandardError)
      RelationshipNotFound = Class.new(DeliveryFailure)

      MAX_RELATIONSHIP_RETRY = 10.freeze

      def perform(post_id, entity, entity_id=nil, relationship_retry = nil)
        unless post = Model::Post.where(:id => post_id).first
          logger.info "Post(#{post_id}) deleted"
          return
        end

        unless entity_id
          entity_id = Model::Entity.first_or_create(entity).id
        end

        q = Model::Relationship.where(:user_id => post.user_id, :entity_id => entity_id)
        relationship = q.where(Sequel.~(:remote_credentials_id => nil)).first || q.first

        if relationship && !relationship.active
          relationship_retry ||= { 'retries' => 0 }

          if relationship_retry['retries'] >= MAX_RELATIONSHIP_RETRY
            # no viable relationship after 396 seconds
            # raise error and let sidekiq take over with a more aggressive backoff
            raise RelationshipNotFound.new("No viable Relationship(#{post.user_id}, #{entity_id})")
          else
            # slowly backoff (1, 2, 5, 10, 17, 26, 37, 50, 65, 82, and 101 seconds)
            delay = 1 + (relationship_retry['retries'] ** 2)

            logger.warn "Failed to deliver Post(#{post_id}) to Entity(#{entity}), No viable relationship exists. Will retry in #{delay}s."

            relationship_retry['retries'] += 1
            NotificationDeliverer.perform_in(delay, post_id, entity, entity_id, relationship_retry)
            return
          end
        end

        unless relationship
          logger.info "Creating relationship to deliver Post(#{post_id}) to Entity(#{entity})."

          RelationshipInitiation.perform_async(post.user_id, entity_id, post_id)
          return
        end

        client = relationship.client

        current_user = Model::User.where(:id => post.user_id).first

        res = client.post.update(post.entity, post.public_id, post.as_json(:delivery => true), {}, :notification => true)

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
