Fabricator(:follower, :class_name => "TentServer::Model::Follower") do |f|
  f.entity "https://smith.example.com"
  f.public true
  f.licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  f.groups { ["family", "friends"].map {|name| g = Fabricate(:group); g.name = name; g.save!; g.public_id } }
end
