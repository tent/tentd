Sequel.migration do
  up do
    create_table(:post_versions_attachments) do
      foreign_key :post_version_id, :post_versions, :key=>[:id], :on_delete=> :cascade, :on_update=> :cascade
      foreign_key :post_attachment_id, :post_attachments, :key=>[:id], :on_delete=> :cascade, :on_update=> :cascade

      index [:post_version_id], :name=>:index_post_versions_attachments_post_version
      index [:post_attachment_id], :name=>:index_post_versions_attachments_attachment
      index [:post_version_id, :post_attachment_id], :name => :index_post_versions_attachments, :unique => true
    end

    create_table(:post_versions_mentions) do
      foreign_key :post_version_id, :post_versions, :key=>[:id], :on_delete=> :cascade, :on_update=> :cascade
      foreign_key :mention_id, :mentions, :key=>[:id], :on_delete=> :cascade, :on_update=> :cascade

      index [:post_version_id], :name=>:index_post_versions_mentions_post_version
      index [:mention_id], :name=>:index_post_versions_mentions_mention_id
      index [:post_version_id, :mention_id], :name => :index_post_versions_mentions, :unique => true
    end

    sql = <<SQL
      INSERT INTO post_versions_attachments
      SELECT id AS post_attachment_id, post_version_id FROM post_attachments
      WHERE post_attachments.post_version_id IS NOT NULL;

      INSERT INTO post_versions_mentions
      SELECT id AS mention_id, post_version_id FROM mentions
      WHERE mentions.post_version_id IS NOT NULL;
SQL
    self[sql]

    alter_table(:post_attachments) do
      drop_column(:post_version_id)
    end

    alter_table(:mentions) do
      drop_column(:post_version_id)
    end
  end

  down do
    alter_table(:post_attachments) do
      add_foreign_key :post_version_id, :post_versions, :key=>[:id], :on_delete=>:cascade, :on_update=>:cascade

      index [:post_version_id], :name=>:index_post_attachments_post_version
    end

    alter_table(:mentions) do
      add_foreign_key :post_version_id, :post_versions, :key=>[:id], :on_delete=>:cascade, :on_update=>:cascade

      index [:post_version_id], :name=>:index_mentions_post_version
    end

    sql = <<SQL
      UPDATE post_attachments
      SET post_version_id = post_version_attachments.post_version_id
      FROM post_version_attachments
      WHERE post_version_attachments.post_attachment_id = post_attachments.id;

      UPDATE mentions
      SET post_version_id = post_version_mentions.post_version_id
      FROM post_version_mentions
      WHERE post_version_mentions.mention_id = mentions.id;
SQL
    self[sql]

    drop_table(:post_versions_attachments)
    drop_table(:post_versions_mentions)
  end
end
