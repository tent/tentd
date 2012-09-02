Fabricator(:post_attachment, :class_name => "TentServer::Model::PostAttachment") do |f|
  post
  f.category 'foo-category'
  f.type 'text/plain'
  f.name 'asdf.txt'
  f.data '12345'
  f.size 5
end
