Fabricator(:notification_subscription, :class_name => 'TentD::Model::NotificationSubscription') do |f|
  f.type_base 'https://tent.io/types/post/status'
  f.type_version '0.1.0'
end
