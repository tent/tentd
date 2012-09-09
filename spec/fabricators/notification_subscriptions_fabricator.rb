Fabricator(:notification_subscription, :class_name => 'TentD::Model::NotificationSubscription') do |f|
  f.type_base 'https://tent.io/types/posts/status'
end
