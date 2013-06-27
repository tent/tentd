module TentD
  module Model

    class DeliveryFailure < Sequel::Model(TentD.database[:delivery_failures])
      def self.find_or_create(entity, post, status, reason)
        delivery_failure = create(
          :user_id => post.user_id,
          :failed_post_id => post.id,
          :entity => entity,
          :status => status,
          :reason => reason
        )

        ref = {
          'entity' => post.entity,
          'post' => post.public_id,
          'version' => post.version,
          'type' => post.type
        }

        type = TentType.new("https://tent.io/types/delivery-failure/v0#")
        type.fragment = TentType.new(post.type).to_s(:fragment => false)

        post = PostBuilder.create_from_env(
          'current_user' => post.user,
          'data' => {
            'type' => type.to_s,
            'refs' => [ ref ],
            'content' => {
              'entity' => entity,
              'status' => status,
              'reason' => reason
            }
          }
        )

        delivery_failure.update(:post_id => post.id)
        delivery_failure
      rescue Sequel::UniqueConstraintViolation => e
        where(
          :user_id => post.user_id,
          :failed_post_id => post.id,
          :entity => entity,
          :status => status
        ).first
      end
    end

  end
end
