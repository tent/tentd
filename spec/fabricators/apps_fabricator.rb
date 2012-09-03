Fabricator(:app, :class_name => 'TentD::Model::App') do
  name "MicroBlogger"
  description "Manages your status updates"
  url "https://microbloggerapp.example.com"
  icon "https://microbloggerapp.example.com/icon.png"
  redirect_uris ["https://microbloggerapp.example.com/auth/callback?foo=bar"]
  scopes { Hash.new(
    "read_posts" => "Can read your posts",
    "create_posts" => "Can create posts on your behalf"
  ) }
end
