Fabricator(:post, :class_name => "TentServer::Model::Post") do
  entity URI("https://smith.example.com")
  scope 'limited'
  type   URI("https://tent.io/types/posts/status")
  licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  groups { ["family", "friends"].map {|name| g = Fabricate(:group); g.name = name; g.save!; g.id.to_s } }
  recipients ["https://alex.example.com", "https://john.example.org"]
  content {{ 'text' => "Debitis exercitationem et cum dolores dolor laudantium. Delectus sit eius id. Totam voluptatem et sunt consectetur sed facere debitis. Quia molestias ratione." }}
  published_at { |attrs| Time.now }
end
