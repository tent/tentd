Sequel.migration do
  change do
    create_table(:permissions) do
      primary_key :id
      foreign_key :post_id
      foreign_key :group_id
      foreign_key :following_id
      foreign_key :follower_visibility_id
      foreign_key :follower_access_id
      foreign_key :profile_id_info
    end
  end
end
