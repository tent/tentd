
Sequel.migration do
  change do
    alter_table(:app_authorizations) do
      add_column :tent_expires_at, Integer
    end
  end
end
