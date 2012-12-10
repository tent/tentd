
Sequel.migration do
  change do
    alter_table(:app_authorizations) do
      add_column :expires_at, Integer
    end
  end
end
