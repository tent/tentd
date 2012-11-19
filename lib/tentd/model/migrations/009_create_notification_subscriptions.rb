Sequel.migration do
  change do
    create_table(:notification_subscriptions) do
      primary_key :id
      foreign_key :user_id, :users
      foreign_key :follower_id, :followers
      foreign_key :app_authorization_id, :app_authorizations

      DateTime :created_at
      DateTime :updated_at
    end
  end
end
