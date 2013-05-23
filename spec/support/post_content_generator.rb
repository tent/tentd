def content_for_post_type(type)
  case type
  when %r|/app/|
    generate_app_content
  when %r|/status/|
    generate_status_content
  else
    Hash.new
  end
end

def generate_app_content
  {
    :name => "Example App Name",
    :description => "Example App Description",
    :url => "http://someapp.example.com",
    :redirect_uri => "http://someapp.example.com/oauth/callback",
    :post_types => {
      :read => %w( https://tent.io/types/status/v0# ),
      :write => %w( https://tent.io/types/status/v0# )
    },
    :scopes => %w( import_posts )
  }
end

def generate_status_content
  {
    :text => "The quick brown fox jumps over the lazy dog into a pool of red dye. The quick red fox jumps over the lazy dog again who becomes very confused and starts running in circles before finally falling over in a fit of dizziness, tail in pool. Then it made sense." # .size => 256
  }
end

def generate_app_icon_attachment
  {
    :content_type => "image/png",
    :category => 'icon',
    :name => 'appicon.png',
    :data => "Fake image data"
  }
end
