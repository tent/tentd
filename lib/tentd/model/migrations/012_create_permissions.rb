Sequel.migration do
  change do
    create_table(:permissions) do
      primary_key :id
      foreign_key :post_id
      foreign_key :group_id
      foreign_key :following_id
      foreign_key :follower_id_visibility
      foreign_key :follower_id_access
      foreign_key :profile_id_info
    end
  end
end
