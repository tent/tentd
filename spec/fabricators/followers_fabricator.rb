Fabricator(:follower, :class_name => "TentD::Model::Follower") do |f|
  f.transient :server_urls
  f.entity "https://smith.example.com"
  f.public true
  f.licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  f.groups { ["family", "friends"].map {|name| Fabricate(:group, :name => name).public_id } }
  f.notification_path "notifications/asdf"
  f.profile { |f|
    { TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI =>
      { :entity => f[:entity], :licenses => f[:licenses], :servers => Array(f[:server_urls] || ["https://example.com"]) }
    }.to_json
  }
  f.updated_at { Time.now }
end
