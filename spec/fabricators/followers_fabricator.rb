Fabricator(:follower, :class_name => "TentD::Model::Follower") do |f|
  f.entity "https://smith.example.com"
  f.public true
  f.licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  f.groups { ["family", "friends"].map {|name| g = Fabricate(:group); g.name = name; g.save!; g.public_id } }
  profile { |f|
    { 'https://tent.io/types/info/core/v0.1.0' =>
      { :entity => f[:entity], :licenses => f[:licenses], :servers => ["https://example.com"] }
    }.to_json
  }
  f.updated_at { Time.now }
end
