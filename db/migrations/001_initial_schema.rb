Sequel.migration do
  change do
    create_table(:app_authorizations) do
      primary_key :id
      column :public_id, "text", :null=>false
      column :post_types, "text[]", :default=>"{}"
      column :profile_info_types, "text[]", :default=>"{}"
      column :scopes, "text[]", :default=>"{}"
      column :token_code, "text"
      column :mac_key_id, "text"
      column :mac_key, "text"
      column :mac_algorithm, "text", :default=>"hmac-sha-256"
      column :mac_timestamp_delta, "integer"
      column :notification_url, "text"
      column :follow_url, "text"
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :app_id, "integer", :null=>false
      
      index [:app_id], :name=>:index_app_authorizations_app
      index [:mac_key_id], :name=>:unique_app_authorizations_mac_key_id, :unique=>true
      index [:token_code], :name=>:unique_app_authorizations_token_code, :unique=>true
      index [:public_id], :name=>:unique_app_authorizations_upublic_id, :unique=>true
    end
    
    create_table(:apps) do
      primary_key :id
      column :public_id, "text", :null=>false
      column :name, "text", :null=>false
      column :description, "text"
      column :url, "text", :null=>false
      column :icon, "text"
      column :redirect_uris, "text[]", :default=>"{}"
      column :scopes, "text", :default=>"{}"
      column :mac_key_id, "text"
      column :mac_key, "text"
      column :mac_algorithm, "text", :default=>"hmac-sha-256"
      column :mac_timestamp_delta, "integer"
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :user_id, "integer", :null=>false
      
      index [:user_id], :name=>:index_apps_user
      index [:mac_key_id], :name=>:unique_apps_mac_key_id, :unique=>true
      index [:public_id], :name=>:unique_apps_upublic_id, :unique=>true
    end
    
    create_table(:followers) do
      primary_key :id
      column :public_id, "text", :null=>false
      column :groups, "text[]", :default=>"{}"
      column :entity, "text", :null=>false
      column :public, "boolean", :default=>true
      column :profile, "text", :default=>"{}"
      column :licenses, "text[]", :default=>"{}"
      column :notification_path, "text", :null=>false
      column :mac_key_id, "text"
      column :mac_key, "text"
      column :mac_algorithm, "text", :default=>"hmac-sha-256"
      column :mac_timestamp_delta, "integer"
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :user_id, "integer", :null=>false
      
      index [:user_id], :name=>:index_followers_user
      index [:mac_key_id], :name=>:unique_followers_mac_key_id, :unique=>true
      index [:public_id], :name=>:unique_followers_upublic_id, :unique=>true
    end
    
    create_table(:followings) do
      primary_key :id
      column :public_id, "text", :null=>false
      column :remote_id, "text"
      column :groups, "text[]", :default=>"{}"
      column :entity, "text", :null=>false
      column :public, "boolean", :default=>true
      column :profile, "text", :default=>"{}"
      column :licenses, "text[]", :default=>"{}"
      column :mac_key_id, "text"
      column :mac_key, "text"
      column :mac_algorithm, "text"
      column :mac_timestamp_delta, "integer"
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :confirmed, "boolean", :default=>true
      column :user_id, "integer", :null=>false
      
      index [:user_id], :name=>:index_followings_user
      index [:public_id], :name=>:unique_followings_upublic_id, :unique=>true
    end
    
    create_table(:groups) do
      primary_key :id
      column :public_id, "text", :null=>false
      column :name, "text", :null=>false
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :user_id, "integer", :null=>false
      
      index [:user_id], :name=>:index_groups_user
      index [:public_id], :name=>:unique_groups_upublic_id, :unique=>true
    end
    
    create_table(:notification_subscriptions) do
      primary_key :id
      column :type_base, "text", :null=>false
      column :type_view, "text"
      column :type_version, "text"
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :user_id, "integer", :null=>false
      column :app_authorization_id, "integer"
      column :follower_id, "integer"
      
      index [:app_authorization_id], :name=>:index_notification_subscriptions_app_authorization
      index [:follower_id], :name=>:index_notification_subscriptions_follower
      index [:user_id], :name=>:index_notification_subscriptions_user
    end
    
    create_table(:permissions) do
      primary_key :id
      column :visible, "boolean", :default=>true
      column :post_id, "integer"
      column :group_public_id, "text"
      column :following_id, "integer"
      column :follower_visibility_id, "integer"
      column :follower_access_id, "integer"
      column :profile_info_id, "integer"
      
      index [:follower_access_id], :name=>:index_permissions_follower_access
      index [:follower_visibility_id], :name=>:index_permissions_follower_visibility
      index [:following_id], :name=>:index_permissions_following
      index [:group_public_id], :name=>:index_permissions_group
      index [:post_id], :name=>:index_permissions_post
      index [:profile_info_id], :name=>:index_permissions_profile_info
    end
    
    create_table(:post_attachments) do
      primary_key :id
      column :type, "text", :null=>false
      column :category, "text", :null=>false
      column :name, "text", :null=>false
      column :data, "text", :null=>false
      column :size, "integer", :null=>false
      column :created_at, "timestamp without time zone", :null=>false
      column :updated_at, "timestamp without time zone", :null=>false
      column :post_id, "integer"
      column :post_version_id, "integer"
      
      index [:post_id], :name=>:index_post_attachments_post
      index [:post_version_id], :name=>:index_post_attachments_post_version
    end
    
    create_table(:post_versions) do
      primary_key :id
      column :type_base, "text", :null=>false
      column :type_view, "text"
      column :type_version, "text"
      column :version, "integer", :null=>false
      column :entity, "text"
      column :public_id, "text", :null=>false
      column :public, "boolean", :default=>false
      column :licenses, "text[]", :default=>"{}"
      column :content, "text", :default=>"{}"
      column :views, "text", :default=>"{}"
      column :published_at, "timestamp without time zone"
      column :received_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :app_name, "text"
      column :app_url, "text"
      column :original, "boolean", :default=>false
      column :user_id, "integer", :null=>false
      column :post_id, "integer", :null=>false
      column :app_id, "integer"
      column :following_id, "integer"
      
      index [:app_id], :name=>:index_post_versions_app
      index [:following_id], :name=>:index_post_versions_following
      index [:post_id], :name=>:index_post_versions_post
      index [:user_id], :name=>:index_post_versions_user
    end
    
    create_table(:posts) do
      primary_key :id
      column :public_id, "text", :null=>false
      column :type_base, "text", :null=>false
      column :type_view, "text"
      column :type_version, "text"
      column :entity, "text"
      column :public, "boolean", :default=>false
      column :licenses, "text[]", :default=>"{}"
      column :content, "text", :default=>"{}"
      column :views, "text", :default=>"{}"
      column :published_at, "timestamp without time zone"
      column :received_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :app_name, "text"
      column :app_url, "text"
      column :original, "boolean", :default=>false
      column :user_id, "integer", :null=>false
      column :app_id, "integer"
      column :following_id, "integer"
      
      index [:app_id], :name=>:index_posts_app
      index [:following_id], :name=>:index_posts_following
      index [:user_id], :name=>:index_posts_user
      index [:public_id, :entity], :name=>:unique_posts_upublic_id, :unique=>true
    end
    
    create_table(:profile_info) do
      primary_key :id
      column :type_base, "text", :null=>false
      column :type_view, "text"
      column :type_version, "text"
      column :public, "boolean", :default=>false
      column :content, "text", :default=>"{}"
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :user_id, "integer", :null=>false
      
      index [:user_id], :name=>:index_profile_info_user
    end
    
    create_table(:users) do
      primary_key :id
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
    end
    
    create_table(:mentions) do
      primary_key :id
      column :entity, "text", :null=>false
      column :original_post, "boolean", :default=>false
      column :mentioned_post_id, "text"
      foreign_key :post_id, :posts, :key=>[:id], :on_delete=>:cascade, :on_update=>:cascade
      foreign_key :post_version_id, :post_versions, :key=>[:id], :on_delete=>:cascade, :on_update=>:cascade
      
      index [:post_id], :name=>:index_mentions_post
      index [:post_version_id], :name=>:index_mentions_post_version
    end
  end
end
