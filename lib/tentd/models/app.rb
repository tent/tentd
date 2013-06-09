module TentD
  module Model

    class App < Sequel::Model(TentD.database[:apps])
      plugin :serialization
      serialize_attributes :pg_array, :read_post_types, :read_post_type_ids, :write_post_types, :scopes

      def self.find_by_client_id(current_user, client_id)
        qualify.join(:posts, :posts__id => :apps__post_id).where(:posts__user_id => current_user.id, :posts__public_id => client_id).first
      end

      def self.update_or_create_from_post(post)
        attrs = {
          :notification_url => post.content['notification_url'],
        }

        if app = first(:post_id => post.id)
          update(attrs) if attrs.any? do |k,v|
            app.send(k) != v
          end

          app
        else
          credentials_post = Model::Credentials.generate(User.first(:id => post.user_id), post, :bidirectional_mention => true)

          create(attrs.merge(
            :user_id => post.user_id,
            :post_id => post.id,
            :credentials_post_id => credentials_post.id,
            :hawk_key => credentials_post.content['hawk_key']
          ))
        end
      end
    end

  end
end
