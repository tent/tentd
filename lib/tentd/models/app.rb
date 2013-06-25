module TentD
  module Model

    class App < Sequel::Model(TentD.database[:apps])
      plugin :serialization
      serialize_attributes :pg_array, :read_types, :read_type_ids, :write_post_types, :scopes, :notification_type_base_ids, :notification_type_ids

      plugin :paranoia if Model.soft_delete

      def self.find_by_client_id(current_user, client_id)
        qualify.join(:posts, :posts__id => :apps__post_id).where(:posts__user_id => current_user.id, :posts__public_id => client_id).first
      end

      def self.subscriber_query(post, options = {})
        q = Query.new(App)

        if columns = options.delete(:select)
          q.select_columns = Array(columns)
        end

        q.query_conditions << "user_id = ?"
        q.query_bindings << post.user_id

        q.query_conditions << "notification_url IS NOT NULL"
        q.query_conditions << "notification_type_ids IS NOT NULL"
        q.query_conditions << "read_type_ids IS NOT NULL"

        q.query_conditions << "credentials_post_id IS NOT NULL"

        q.query_conditions << ["AND",
          ["OR",
            "(?)::text = ANY (notification_type_ids)",
            "(?)::text = ANY (notification_type_ids)"
          ],
          ["OR",
            "(?)::text = ANY (read_type_ids)",
            "(?)::text = ANY (read_type_ids)",
            "(?)::text = ANY (read_type_ids)"
          ]
        ]

        all_type_id = Type.find_or_create_full('all').id

        # notification_type_ids
        q.query_bindings << post.type_id
        q.query_bindings << all_type_id

        # read_type_ids
        q.query_bindings << post.type_id
        q.query_bindings << post.type_base_id
        q.query_bindings << all_type_id

        q
      end

      def self.subscribers?(post)
        subscriber_query(post).any?
      end

      def self.subscribers(post, options = {})
        subscriber_query(post, options).all
      end

      def self.update_or_create_from_post(post, options = {})
        attrs = {
          :notification_url => post.content['notification_url'],
        }

        if post.content['notification_post_types'].to_a.any?
          types = Type.find_or_create_types(post.content['notification_post_types'])
          attrs[:notification_type_ids] = types.map(&:id).uniq
        end

        if app = qualify.join(:posts, :posts__id => :apps__post_id).where(:apps__user_id => post.user_id, :posts__public_id => post.public_id).first
          app.update(attrs) if attrs.any? do |k,v|
            app.send(k) != v
          end

          app
        else
          if options[:create_credentials]
            credentials_post = Model::Credentials.generate(User.first(:id => post.user_id), post, :bidirectional_mention => true)

            attrs[:credentials_post_id] = credentials_post.id
            attrs[:hawk_key] = credentials_post.content['hawk_key']
          end

          create(attrs.merge(
            :user_id => post.user_id,
            :post_id => post.id
          ))
        end
      end

      def self.update_app_auth(auth_post, public_id)
        return unless public_id

        app = qualify.join(:posts, :posts__id => :apps__post_id).where(
          :posts__user_id => auth_post.user_id,
          :posts__public_id => public_id
        ).first
        return unless app

        app.update(
          :auth_post_id => auth_post.id,
          :read_types => auth_post.content['post_types']['read'].to_a,
          :read_type_ids => Type.find_types(auth_post.content['post_types']['read'].to_a).map(&:id).uniq,
          :write_post_types => auth_post.content['post_types']['write'].to_a
        )
      end

      def self.update_credentials(credentials_post, public_id)
        return unless public_id

        app = qualify.join(:posts, :posts__id => :apps__post_id).where(
          :posts__user_id => credentials_post.user_id,
          :posts__public_id => public_id
        ).first
        return unless app

        app.update(:credentials_post_id => credentials_post.id, :hawk_key => credentials_post.content['hawk_key'])
      end

      def self.update_app_auth_credentials(credentials_post, public_id)
        return unless public_id

        app = qualify.join(:posts, :posts__id => :apps__auth_post_id).where(
          :posts__user_id => credentials_post.user_id,
          :posts__public_id => public_id
        ).first
        return unless app

        app.update(
          :auth_hawk_key => credentials_post.content['hawk_key'],
          :auth_credentials_post_id => credentials_post.id,
        )
      end
    end

  end
end
