Fabricator(:follow, :class_name => "TentServer::Model::Follow") do
  entity URI("https://smith.example.com")
  licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  groups { ["family", "friends"].map {|name| g = Fabricate(:group); g.name = name; g.save!; g.id.to_s } }
end
