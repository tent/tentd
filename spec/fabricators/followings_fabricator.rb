Fabricator(:following, :class_name => "TentServer::Model::Following") do
  entity URI("https://smith.example.com")
  licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  groups { ["family", "friends"].map {|name| g = Fabricate(:group); g.name = name; g.save!; g.public_uid } }
end
