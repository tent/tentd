Sequel.migration do
  change do
    create_table(:posts) do
      primary_key :id
      foreign_key :user_id, :users
      foreign_key :app_id, :apps
      foreign_key :follower_id, :followers

      String   :public_id
      String   :entity,      :text => true
      Boolean  :public
      String   :licenses,    :text => true
      String   :content,     :text => true
      String   :views,       :text => true
      String   :app_name,    :text => true
      String   :app_url,     :text => true
      Boolean  :original
      String   :type_base,   :text => true
      String   :type_view
      String   :type_version
      DateTime :published_at
      DateTime :received_at
      DateTime :updated_at
      DateTime :deleted_at

      index [:entity, :public_id], :unique => true
    end
  end
end
