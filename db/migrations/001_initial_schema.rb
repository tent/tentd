Sequel.migration do
  change do

    # Contents:
    #   - entities
    #   - types
    #   - users
    #   - posts
    #   - apps
    #   - relationships
    #   - subscriptions
    #   - groups
    #   - mentions
    #   - refs
    #   - attachments
    #   - posts_attachments
    #   - permissions

    create_table(:entities) do
      primary_key :id

      column :entity     , "text"   , :null => false

      index [:entity], :name => :unique_entities, :unique => true
    end

    create_table(:types) do
      primary_key :id

      column :base     , "text"   , :null => false
      column :version  , "text"   , :null => false
      column :fragment , "text"

      index [:base, :version, :fragment], :name => :unique_types, :unique => true
    end

    create_table(:users) do
      primary_key :id
      foreign_key :entity_id, :entities

      column :entity       , "text"   , :null => false # entities.entity
      column :meta_post_id , "bigint" # posts.id

      column :server_credentials , "text"   , :null => false
      column :deleted_at         , "timestamp without time zone"

      index [:entity_id], :name => :unique_users, :unique => true
    end

    create_table(:posts) do
      primary_key :id
      foreign_key :user_id          , :users
      foreign_key :type_id          , :types
      foreign_key :type_base_id     , :types
      foreign_key :entity_id        , :entities

      column :type                 , "text"                   , :null => false # types.type + '#' + types.fragment
      column :entity               , "text"                   , :null => false # entities.entity
      column :original_entity      , "text"

      # Timestamps
      # milliseconds since unix epoch
      # bigint max value: 9,223,372,036,854,775,807

      column :published_at         , "bigint"                 , :null => false
      column :received_at          , "bigint"
      column :version_published_at , "bigint"
      column :version_received_at  , "bigint"
      column :deleted_at           , "timestamp without time zone"

      column :app_id               , "text"
      column :app_name             , "text"
      column :app_url              , "text"

      column :public               , "boolean"                , :default => false
      column :permissions_entities , "text[]"                 , :default => "{}"
      column :permissions_groups   , "text[]"                 , :default => "{}"

      column :mentions             , "text" # serialized json
      column :refs                 , "text" # serialized json
      column :attachments          , "text" # serialized json

      column :version_parents      , "text" # serialized json
      column :version              , "text"                   , :null => false
      column :version_message      , "text"

      column :public_id            , "text"
      column :licenses             , "text" # serialized json
      column :content              , "text" # serialized json

      index [:user_id], :name => :index_posts_user
      index [:user_id, :public_id], :name => :index_posts_user_public_id
      index [:user_id, :entity_id, :public_id, :version], :name => :unique_posts, :unique => true
    end

    create_table(:parents) do
      foreign_key :post_id
      foreign_key :parent_post_id

      column :version, "text"
      column :post, "text"

      index [:post_id, :version, :post], :name => :unique_post_parents, :unique => true
    end

    create_table(:delivery_failures) do
      primary_key :id
      foreign_key :user_id        , :users
      foreign_key :failed_post_id , :posts # post for which delivery failed
      foreign_key :post_id        , :posts # delivery failure post

      column :entity , "text" , :null => false # entity to whom delivery failed
      column :status , "text" , :null => false
      column :reason , "text" , :null => false

      index [:user_id, :failed_post_id, :entity, :status], :name => :unique_delivery_failrues, :unique => true
    end

    create_table(:apps) do
      primary_key :id
      foreign_key :user_id                  , :users
      foreign_key :post_id                  , :posts
      foreign_key :auth_post_id             , :posts
      foreign_key :credentials_post_id      , :posts
      foreign_key :auth_credentials_post_id , :posts

      column :hawk_key              , "text" # credentials_post.content.hawk_key
      column :auth_hawk_key         , "text" # auth_credentials_post.content.hawk_key

      column :notification_url      , "text" # post.content.notification_url
      column :notification_type_ids , "text[]"

      column :read_types            , "text[]" # auth_post.content.types.read
      column :read_type_ids         , "text[]" # auth_post.content.types.read ids
      column :write_types           , "text[]" # auth_post.content.types.write
      column :scopes                , "text[]" # auth_post.content.scopes
      column :deleted_at            , "timestamp without time zone"

      index [:user_id, :auth_hawk_key], :name => :index_apps_user_auth_hawk_key
      index [:user_id, :post_id], :name => :unique_app, :unique => true
    end

    create_table(:relationships) do
      primary_key :id
      foreign_key :user_id             , :users
      foreign_key :entity_id           , :entities
      foreign_key :post_id             , :posts
      foreign_key :meta_post_id        , :posts
      foreign_key :credentials_post_id , :posts
      foreign_key :type_id             , :types # type of relationship, posts.type where posts.id = post_id

      column :active                , "boolean"
      column :entity                , "text"
      column :remote_credentials_id , "text" # remote_credentials.id (public_id)
      column :remote_credentials    , "text" # serialized as json (used to sign outgoing requests)
      column :deleted_at            , "timestamp without time zone"

      index [:user_id, :type_id], :name => :index_relationships_user_type
      index [:user_id, :entity_id], :name => :unique_relationships, :unique => true
    end

    create_table(:subscriptions) do
      primary_key :id
      foreign_key :user_id              , :users
      foreign_key :post_id              , :posts
      foreign_key :subscriber_entity_id , :entities # entity of subscriber
      foreign_key :entity_id            , :entities # entity subscribed to
      foreign_key :type_id              , :types # null if type = 'all'

      column :subscriber_entity , "text" # entity of subscriber
      column :entity            , "text" # entity subscribed to
      column :type              , "text" # type uri or 'all'
      column :deleted_at        , "timestamp without time zone"

      index [:user_id, :type_id], :name => :index_subscriptions_user_type
      index [:user_id, :entity_id, :subscriber_entity_id, :type_id], :name => :unique_subscriptions, :unique => true
    end

    create_table(:groups) do
      primary_key :id
      foreign_key :user_id , :users
      foreign_key :post_id , :posts

      index [:user_id, :post_id], :name => :unique_groups, :unique => true
    end

    create_table(:mentions) do
      foreign_key :user_id   , :users
      foreign_key :post_id   , :posts
      foreign_key :entity_id , :entities
      foreign_key :type_id   , :types

      column :type       , "text"
      column :entity     , "text"
      column :post       , "text"
      column :public     , "boolean" , :default => true

      index [:user_id, :post_id, :entity_id, :post], :name => :unique_mentions, :unique => true
    end

    create_table(:refs) do
      foreign_key :user_id   , :users
      foreign_key :post_id   , :posts
      foreign_key :entity_id , :entities

      column :post       , "text"

      index [:user_id, :post_id, :entity_id, :post], :name => :unique_refs, :unique => true
    end

    # Fallback data store for attachments
    # metadata is kept in posts.attachment as serialized json
    #
    # No need to scope by user as attachment data is immutable
    create_table(:attachments) do
      primary_key :id

      column :digest   , "text"     , :null => false
      column :size     , "bigint"   , :null => false
      column :data_oid , "bigint"   , :null => false

      index [:digest, :size], :name => :unique_attachments, :unique => true
    end

    # Join table for post attachment data
    create_table(:posts_attachments) do
      foreign_key :post_id       , :posts       , :on_delete => :cascade
      foreign_key :attachment_id , :attachments , :on_delete => :cascade

      column :digest       , "text"
      column :content_type , "text"   , :null => false

      index [:post_id, :attachment_id, :content_type], :name => :unique_posts_attachments, :unique => true
    end

    create_table(:permissions) do
      foreign_key :user_id   , :users
      foreign_key :post_id   , :posts
      foreign_key :entity_id , :entities
      foreign_key :group_id  , :groups

      index [:user_id, :post_id, :entity_id, :group_id], :name => :unique_permissions, :unique => true
    end

  end
end
