Fabricator(:post_attachment, :class_name => "TentD::Model::PostAttachment") do |f|
  post
  f.category 'foo-category'
  f.type 'text/plain'
  f.name 'asdf.txt'
  f.data "NTQzMjE=\n"
  f.size 5
end
