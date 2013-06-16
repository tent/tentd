module TentD
  module Model

    class Subscription < Sequel::Model(TentD.database[:subscriptions])
      attr_writer :post
      def self.find_or_create(post_attrs)
        unless target_entity = (post_attrs[:mentions].to_a.first || {})['entity']
          raise Post::CreateFailure.new("Subscription must mention an entity! #{post_attrs[:mentions].inspect}")
        end

        unless subscription = where(:user_id => post_attrs[:user_id], :type => post_attrs[:content]['type']).first
          type = Type.find_or_create_full(post_attrs[:content]['type'])
          post = Post.create(post_attrs)

          target_entity_id = Entity.first_or_create(target_entity).id

          existing_relationship = Relationship.where(:user_id => post.user_id, :entity_id => target_entity_id).first

          subscription = create(
            :user_id => post.user_id,
            :post_id => post.id,
            :subscriber_entity_id => post.entity_id,
            :entity_id => target_entity_id,
            :entity => target_entity,
            :relationship_id => (existing_relationship ? existing_relationship.id : nil),
            :type_id => (type ? type.id : nil), # nil if 'all'
            :type => post.content['type']
          )

          unless existing_relationship
            Worker::RelationshipInitiation.perform_async(post.user_id, target_entity_id, subscription.post_id)
          end

          subscription.post = post
        end

        subscription
      end

      def self.create_from_notification(current_user, post_attrs)
        unless target_entity = (post_attrs[:mentions].to_a.first || {})['entity']
          raise Post::CreateFailure.new("Subscription must mention an entity! #{post_attrs[:mentions].inspect}")
        end

        unless subscription = where(:user_id => current_user.id, :type => post_attrs[:content]['type']).first
          type = Type.find_or_create_full(post_attrs[:content]['type'])
          post = Post.create(post_attrs)

          # Don't create a subscription record if we're not the target
          unless target_entity == current_user.entity
            subscription = new
            subscription.post = post
            return subscription
          end

          target_entity_id = current_user.entity_id

          # subscriber is responsible for initiating a relationship
          existing_relationship = Relationship.where(:user_id => post.user_id, :entity_id => target_entity_id).first

          subscription = create(
            :user_id => post.user_id,
            :post_id => post.id,
            :subscriber_entity_id => post.entity_id,
            :entity_id => target_entity_id,
            :entity => target_entity,
            :relationship_id => (existing_relationship ? existing_relationship.id : nil),
            :type_id => (type ? type.id : nil), # nil if 'all'
            :type => post.content['type']
          )

          subscription.post = post
        end

        subscription
      end

      def post
        @post ||= Post.where(:id => self.post_id).first
      end
    end

  end
end
