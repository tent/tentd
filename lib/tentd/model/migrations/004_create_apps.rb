Sequel.migration do
  change do
    create_tabe(:apps) do
      primary_key :id
      foreign_key :user_id, :users

      String :public_id
      String :name, :text => true
      String :description, :text => true
      String :url, :text => true
      String :icon, :text => true
      String :redirect_uris, :text => true
      String :scopes, :text => true
      String :mac_key_id, :unique => true
      String :mac_key
      String :mac_algorithm
      Integer :mac_timestamp_delta
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
    end
  end
end
