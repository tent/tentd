Sequel.migration do
  change do
    create_table(:groups) do
      primary_key :id
      foreign_key :user_id, :users

      String :public_id
      String :name
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
    end
  end
end
