Sequel.migration do
  change do
    create_table(:followers) do
      primary_key :id
      foreign_key :user_id, :users

      String :public_id
      String :remote_id
      String :groups, :text => true
      String :entity, :text => true
      Boolean :public
      String :profile, :text => true
      String :licenses, :text => true
      String :notification_path, :text => true
      String :mac_key_id
      String :mac_key
      String :mac_algorithm
      Integer :mac_timestamp_delta
      Boolean :confirmed
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
    end
  end
end
