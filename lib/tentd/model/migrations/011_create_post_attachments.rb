Sequel.migration do
  change do
    create_table(:post_attachments) do
      primary_key :id
      foreign_key :post_id, :posts
      foreign_key :post_version_id, :post_versions

      String :type, :text => true
      String :category, :text => true
      String :name, :text => true
      String :data, :text => true
      Integer :size

      DateTime :created_at
      DateTime :updated_at
    end
  end
end
