module TentD
  module Model

    class Subscription < Sequel::Model(TentD.database[:subscriptions])
      plugin :paranoia if Model.soft_delete

      attr_writer :post
      attr_accessor :deliver
      def self.find_or_create(post_attrs)
        TentD.logger.debug "Subscription.find_or_create" if TentD.settings[:debug]

        unless target_entity = (post_attrs[:mentions].to_a.first || {})['entity']
          TentD.logger.debug "Subscription.find_or_create: Must mention an entity" if TentD.settings[:debug]

          raise Post::CreateFailure.new("Subscription must mention an entity! #{post_attrs[:mentions].inspect}")
        end

        type = Type.find_or_create_full(post_attrs[:content]['type'])
        target_entity_id = Entity.first_or_create(target_entity).id
        unless subscription = where(:user_id => post_attrs[:user_id], :type_id => type.id, :entity_id => target_entity_id, :subscriber_entity_id => post_attrs[:entity_id]).first
          TentD.logger.debug "Subscription.find_or_create -> Post.create" if TentD.settings[:debug]

          post = Post.create(post_attrs)

          TentD.logger.debug "Subscription.find_or_create -> Subscription.create" if TentD.settings[:debug]

          subscription = create(
            :user_id => post.user_id,
            :post_id => post.id,
            :subscriber_entity_id => post.entity_id,
            :subscriber_entity => post.entity,
            :entity_id => target_entity_id,
            :entity => target_entity,
            :type_id => (type ? type.id : nil), # nil if 'all'
            :type => post.content['type']
          )

          existing_relationship = Relationship.where(:user_id => post.user_id, :entity_id => target_entity_id).first
          unless existing_relationship
            TentD.logger.debug "Subscription.find_or_create -> RelationshipInitiation.perform_async" if TentD.settings[:debug]

            subscription.deliver = false
            Worker::RelationshipInitiation.perform_async(post.user_id, target_entity_id, subscription.post_id)
          end

          subscription.post = post
        end

        subscription
      end

      def self.create_from_notification(current_user, post_attrs, relationship_post)
        TentD.logger.debug "Subscription.create_from_notification" if TentD.settings[:debug]

        unless target_entity = (post_attrs[:mentions].to_a.first || {})['entity']
          TentD.logger.debug "Subscription.create_from_notification: Must mention an entity" if TentD.settings[:debug]

          raise Post::CreateFailure.new("Subscription must mention an entity! #{post_attrs[:mentions].inspect}")
        end

        unless subscription = where(:user_id => current_user.id, :type => post_attrs[:content]['type'], :entity_id => current_user.entity_id, :subscriber_entity_id => post_attrs[:entity_id]).first
          TentD.logger.debug "Subscription.create_from_notification -> Post.create" if TentD.settings[:debug]

          post = Post.create(post_attrs)

          if post.public
            TentD.logger.debug "Subscription.create_from_notification: Make relationship public for Entity(#{post.entity})" if TentD.settings[:debug]

            Relationship.where(
              :user_id => current_user.id,
              :entity_id => post.entity_id
            ).first.set_public
          end

          # Don't create a subscription record if we're not the target
          unless target_entity == current_user.entity
            TentD.logger.debug "Subscription.create_from_notification: We (#{current_user.entity}) are not the target (#{target_entity}), don't create a subscription record" if TentD.settings[:debug]

            subscription = new
            subscription.post = post
            return subscription
          end

          type = Type.find_or_create_full(post_attrs[:content]['type'])
          target_entity_id = current_user.entity_id

          TentD.logger.debug "Subscription.create_from_notification -> Subscription.create" if TentD.settings[:debug]

          subscription = create(
            :user_id => post.user_id,
            :post_id => post.id,
            :subscriber_entity_id => post.entity_id,
            :subscriber_entity => post.entity,
            :entity_id => target_entity_id,
            :entity => target_entity,
            :type_id => (type ? type.id : nil), # nil if 'all'
            :type => post.content['type']
          )

          subscription.post = post
        end

        subscription
      end

      def self.post_destroyed(post)
        where(:post_id => post.id).destroy
      end

      def post
        @post ||= Post.where(:id => self.post_id).first
      end
    end

  end
end
