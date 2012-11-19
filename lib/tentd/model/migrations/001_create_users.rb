Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      DateTime :created_at
      DateTime :updated_at
      DateTime :deleted_at
    end
  end
end
