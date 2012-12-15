Sequel.migration do
  change do
    alter_table(:post_attachments) do
      set_column_allow_null :data, true
    end
  end
end
