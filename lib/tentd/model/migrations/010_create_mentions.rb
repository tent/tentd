Sequel.migration do
  change do
    create_table(:mentions) do
      primary_key :id
      foreign_key :post_id, :posts
      foreign_key :post_version_id, :post_versions

      Boolean :original_post
      String :entity, :text => true
      String :mentioned_post_id
    end
  end
end
