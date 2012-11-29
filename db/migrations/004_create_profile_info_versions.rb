Sequel.migration do
  change do
    create_table(:profile_info_versions) do
      primary_key :id
      column :type_base, "text", :null => false
      column :type_view, "text"
      column :type_version, "text"
      column :version, 'integer', :null => false
      column :public, "boolean", :default => false
      column :content, "text", :default => "{}"
      column :created_at, "timestamp without time zone"
      column :updated_at, "timestamp without time zone"
      column :deleted_at, "timestamp without time zone"
      column :user_id, "integer", :null=>false

      foreign_key :profile_info_id, :profile_info, :key => [:id], :on_delete => :cascade, :on_update => :cascade

      index [:user_id], :name=> :index_profile_info_versions_user
      index [:profile_info_id], :name => :index_profile_info_versions_profile_info
    end
  end
end
