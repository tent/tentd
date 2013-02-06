Sequel.migration do
  change do
    alter_table(:followings) do
      add_column :types, 'text[]', :default => '{}'
    end
  end
end
