module TentD
  module Model

    class Relationship < Sequel::Model(TentD.database[:relationships])
      plugin :serialization
      serialize_attributes :json, :remote_credentials

      attr_writer :post, :credentials_post, :meta_post

      def self.create_initial(current_user, target_entity, relationship = nil)
        type, base_type = Type.find_or_create("https://tent.io/types/relationship/v0#initial")
        published_at_timestamp = TentD::Utils.timestamp

        attrs = {
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp,

          :mentions => [
            { "entity" => target_entity }
          ]
        }

        post = Post.create(attrs)
        post.create_mentions(attrs[:mentions])

        credentials_post = Model::Credentials.generate(current_user, post)

        relationship_attrs = {
          :user_id => current_user.id,
          :entity_id => Entity.first_or_create(target_entity).id,
          :entity => target_entity,
          :post_id => post.id,
          :type_id => post.type_id,
          :credentials_post_id => credentials_post.id,
        }

        if relationship
          relationship.update(relationship_attrs)
        else
          relationship = create(relationship_attrs)
        end

        relationship.post = post
        relationship.credentials_post = credentials_post

        relationship
      end

      def self.create_final(current_user, parts = {})
        remote_relationship = parts.delete(:remote_relationship)
        remote_credentials = parts.delete(:remote_credentials)
        remote_meta_post = parts.delete(:remote_meta_post)
        remote_entity = remote_relationship[:entity]

        type, base_type = Type.find_or_create("https://tent.io/types/relationship/v0#")
        published_at_timestamp = Utils.timestamp

        attrs = {
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp,

          :permissions_entities => [remote_entity]
        }

        attrs[:mentions] = [{
          'entity' => remote_relationship[:entity],
          'type' => remote_relationship[:type],
          'post' => remote_relationship[:id]
        }]

        post = Post.create(attrs)
        post.create_mentions(attrs[:mentions])

        credentials_post = Model::Credentials.generate(current_user, post)

        remote_entity_id = Entity.first_or_create(remote_entity).id

        relationship = create(
          :user_id => current_user.id,
          :entity_id => remote_entity_id,
          :entity => remote_entity,
          :post_id => post.id,
          :type_id => post.type_id,
          :meta_post_id => remote_meta_post.id,
          :credentials_post_id => credentials_post.id,

          :remote_credentials_id => remote_credentials[:id], # for easy lookup
          :remote_credentials => {
            'id' => remote_credentials[:id],
            'hawk_key' => remote_credentials[:content][:hawk_key],
            'hawk_algorithm' => remote_credentials[:content][:hawk_algorithm]
          }
        )

        relationship.post = post
        relationship.credentials_post = credentials_post
        relationship.meta_post = remote_meta_post

        relationship.link_subscriptions

        post.queue_delivery

        relationship
      end

      def post
        @post ||= Post.where(:id => self.post_id).first
      end

      def credentials_post
        @credentials_post ||= Post.where(:id => self.credentials_post_id).first
      end

      def meta_post
        @meta_post ||= Post.where(:id => self.meta_post_id).first
      end

      def finalize
        type, base_type = Type.find_or_create("https://tent.io/types/relationship/v0#")

        post.type = type.type
        post.type_id = type.id
        post.type_base_id = base_type.id

        @post = post.save_version(:public_id => post.public_id)

        self.post_id = post.id
        self.type_id = type.id

        save
      end

      def link_subscriptions
        Subscription.where(
          :user_id => user_id,
          :subscriber_entity_id => entity_id,
          :relationship_id => nil
        ).update(:relationship_id => self.id)
      end
    end

  end
end
