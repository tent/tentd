Sequel.migration do
  change do
    create_table(:profile_info) do
      primary_key :id
      foreign_key :user_id, :users

      Boolean :public
      String :content, :text => true
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
    end
  end
end
