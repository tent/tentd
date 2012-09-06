Fabricator(:app_authorization, :class_name => 'TentD::Model::AppAuthorization') do |f|
  f.notification_url "http://example.com/notifications"
  updated_at { Time.now }
  created_at { Time.now }
end
