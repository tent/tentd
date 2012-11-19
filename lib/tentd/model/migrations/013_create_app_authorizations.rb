Sequel.migration do
  change do
    create_table(:app_authorizations) do
      primary_key :id
      foreign_key :app_id

      String :post_types, :text => true
      String :profile_info_types, :text => true
      String :scopes, :text => true
      String :token_code
      String :mac_key_id
      String :mac_key
      String :mac_algorithm
      Integer :mac_timestamp_delta
      String :notification_url, :text => true
      String :follow_url, :text => true
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
