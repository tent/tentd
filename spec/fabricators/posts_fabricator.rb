Fabricator(:post, :class_name => "TentD::Model::Post") do |f|
  f.entity "https://smith.example.com"
  f.public true
  f.original true
  f.type_base "https://tent.io/types/post/status"
  f.type_version "0.1.0"
  f.licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  f.content {{ 'text' => "Debitis exercitationem et cum dolores dolor laudantium. Delectus sit eius id. Totam voluptatem et sunt consectetur sed facere debitis. Quia molestias ratione." }}
  f.updated_at { |attrs| Time.now }
  f.published_at { |attrs| Time.now }
  f.received_at { |attrs| Time.now }
end
