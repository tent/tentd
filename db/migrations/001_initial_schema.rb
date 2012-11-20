Sequel.migration do
  change do
    create_table(:app_authorizations, :ignore_index_errors=>true) do
      primary_key :id
      String :public_id, :size=>50, :null=>false
      String :post_types, :default=>"{}", :text=>true
      String :profile_info_types, :default=>"{}", :text=>true
      String :scopes, :default=>"{}", :text=>true
      String :token_code, :size=>50
      String :mac_key_id, :size=>50
      String :mac_key, :size=>50
      String :mac_algorithm, :default=>"hmac-sha-256", :size=>50
      Integer :mac_timestamp_delta
      String :notification_url, :text=>true
      String :follow_url, :text=>true
      DateTime :created_at
      DateTime :updated_at
      Integer :app_id, :null=>false
      
      index [:app_id], :name=>:index_app_authorizations_app
      index [:mac_key_id], :name=>:unique_app_authorizations_mac_key_id, :unique=>true
      index [:token_code], :name=>:unique_app_authorizations_token_code, :unique=>true
      index [:public_id], :name=>:unique_app_authorizations_upublic_id, :unique=>true
    end
    
    create_table(:apps, :ignore_index_errors=>true) do
      primary_key :id
      String :public_id, :size=>50, :null=>false
      String :name, :text=>true, :null=>false
      String :description, :text=>true
      String :url, :text=>true, :null=>false
      String :icon, :text=>true
      String :redirect_uris, :default=>"{}", :text=>true
      String :scopes, :default=>"{}", :text=>true
      String :mac_key_id, :size=>50
      String :mac_key, :size=>50
      String :mac_algorithm, :default=>"hmac-sha-256", :size=>50
      Integer :mac_timestamp_delta
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
      Integer :user_id, :null=>false
      
      index [:user_id], :name=>:index_apps_user
      index [:mac_key_id], :name=>:unique_apps_mac_key_id, :unique=>true
      index [:public_id], :name=>:unique_apps_upublic_id, :unique=>true
    end
    
    create_table(:followers, :ignore_index_errors=>true) do
      primary_key :id
      String :public_id, :size=>50, :null=>false
      String :groups, :default=>"{}", :text=>true
      String :entity, :text=>true, :null=>false
      TrueClass :public, :default=>true
      String :profile, :default=>"{}", :text=>true
      String :licenses, :default=>"{}", :text=>true
      String :notification_path, :text=>true, :null=>false
      String :mac_key_id, :size=>50
      String :mac_key, :size=>50
      String :mac_algorithm, :default=>"hmac-sha-256", :size=>50
      Integer :mac_timestamp_delta
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
      Integer :user_id, :null=>false
      
      index [:user_id], :name=>:index_followers_user
      index [:mac_key_id], :name=>:unique_followers_mac_key_id, :unique=>true
      index [:public_id], :name=>:unique_followers_upublic_id, :unique=>true
    end
    
    create_table(:followings, :ignore_index_errors=>true) do
      primary_key :id
      String :public_id, :size=>50, :null=>false
      String :remote_id, :size=>50
      String :groups, :default=>"{}", :text=>true
      String :entity, :text=>true, :null=>false
      TrueClass :public, :default=>true
      String :profile, :default=>"{}", :text=>true
      String :licenses, :default=>"{}", :text=>true
      String :mac_key_id, :size=>50
      String :mac_key, :size=>50
      String :mac_algorithm, :size=>50
      Integer :mac_timestamp_delta
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
      TrueClass :confirmed, :default=>true
      Integer :user_id, :null=>false
      
      index [:user_id], :name=>:index_followings_user
      index [:public_id], :name=>:unique_followings_upublic_id, :unique=>true
    end
    
    create_table(:groups, :ignore_index_errors=>true) do
      primary_key :id
      String :public_id, :size=>50, :null=>false
      String :name, :text=>true, :null=>false
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
      Integer :user_id, :null=>false
      
      index [:user_id], :name=>:index_groups_user
      index [:public_id], :name=>:unique_groups_upublic_id, :unique=>true
    end
    
    create_table(:notification_subscriptions, :ignore_index_errors=>true) do
      primary_key :id
      String :type_base, :text=>true, :null=>false
      String :type_view, :size=>50
      String :type_version, :size=>50
      DateTime :created_at
      DateTime :updated_at
      Integer :user_id, :null=>false
      Integer :app_authorization_id
      Integer :follower_id
      
      index [:app_authorization_id], :name=>:index_notification_subscriptions_app_authorization
      index [:follower_id], :name=>:index_notification_subscriptions_follower
      index [:user_id], :name=>:index_notification_subscriptions_user
    end
    
    create_table(:permissions, :ignore_index_errors=>true) do
      primary_key :id
      TrueClass :visible, :default=>true
      Integer :post_id
      String :group_public_id, :size=>50
      Integer :following_id
      Integer :follower_visibility_id
      Integer :follower_access_id
      Integer :profile_info_id
      
      index [:follower_access_id], :name=>:index_permissions_follower_access
      index [:follower_visibility_id], :name=>:index_permissions_follower_visibility
      index [:following_id], :name=>:index_permissions_following
      index [:group_public_id], :name=>:index_permissions_group
      index [:post_id], :name=>:index_permissions_post
      index [:profile_info_id], :name=>:index_permissions_profile_info
    end
    
    create_table(:post_attachments, :ignore_index_errors=>true) do
      primary_key :id
      String :type, :text=>true, :null=>false
      String :category, :text=>true, :null=>false
      String :name, :text=>true, :null=>false
      String :data, :text=>true, :null=>false
      Integer :size, :null=>false
      DateTime :created_at, :null=>false
      DateTime :updated_at, :null=>false
      Integer :post_id
      Integer :post_version_id
      
      index [:post_id], :name=>:index_post_attachments_post
      index [:post_version_id], :name=>:index_post_attachments_post_version
    end
    
    create_table(:post_versions, :ignore_index_errors=>true) do
      primary_key :id
      String :type_base, :text=>true, :null=>false
      String :type_view, :size=>50
      String :type_version, :size=>50
      Integer :version, :null=>false
      String :entity, :text=>true
      String :public_id, :size=>50, :null=>false
      TrueClass :public, :default=>false
      String :licenses, :default=>"{}", :text=>true
      String :content, :default=>"{}", :text=>true
      String :views, :default=>"{}", :text=>true
      DateTime :published_at
      DateTime :received_at
      DateTime :updated_at
      DateTime :deleted_at
      String :app_name, :text=>true
      String :app_url, :text=>true
      TrueClass :original, :default=>false
      Integer :user_id, :null=>false
      Integer :post_id, :null=>false
      Integer :app_id
      Integer :following_id
      
      index [:app_id], :name=>:index_post_versions_app
      index [:following_id], :name=>:index_post_versions_following
      index [:post_id], :name=>:index_post_versions_post
      index [:user_id], :name=>:index_post_versions_user
    end
    
    create_table(:posts, :ignore_index_errors=>true) do
      primary_key :id
      String :public_id, :size=>50, :null=>false
      String :type_base, :text=>true, :null=>false
      String :type_view, :size=>50
      String :type_version, :size=>50
      String :entity, :text=>true
      TrueClass :public, :default=>false
      String :licenses, :default=>"{}", :text=>true
      String :content, :default=>"{}", :text=>true
      String :views, :default=>"{}", :text=>true
      DateTime :published_at
      DateTime :received_at
      DateTime :updated_at
      DateTime :deleted_at
      String :app_name, :text=>true
      String :app_url, :text=>true
      TrueClass :original, :default=>false
      Integer :user_id, :null=>false
      Integer :app_id
      Integer :following_id
      
      index [:app_id], :name=>:index_posts_app
      index [:following_id], :name=>:index_posts_following
      index [:user_id], :name=>:index_posts_user
      index [:public_id, :entity], :name=>:unique_posts_upublic_id, :unique=>true
    end
    
    create_table(:profile_info, :ignore_index_errors=>true) do
      primary_key :id
      String :type_base, :text=>true, :null=>false
      String :type_view, :size=>50
      String :type_version, :size=>50
      TrueClass :public, :default=>false
      String :content, :default=>"{}", :text=>true
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
      Integer :user_id, :null=>false
      
      index [:user_id], :name=>:index_profile_info_user
    end
    
    create_table(:users) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
    end
    
    create_table(:mentions, :ignore_index_errors=>true) do
      primary_key :id
      String :entity, :text=>true, :null=>false
      TrueClass :original_post, :default=>false
      String :mentioned_post_id, :size=>50
      foreign_key :post_id, :posts, :key=>[:id], :on_delete=>:cascade, :on_update=>:cascade
      foreign_key :post_version_id, :post_versions, :key=>[:id], :on_delete=>:cascade, :on_update=>:cascade
      
      index [:post_id], :name=>:index_mentions_post
      index [:post_version_id], :name=>:index_mentions_post_version
    end
  end
end
