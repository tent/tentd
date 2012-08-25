module TentServer
  class API
    class Posts
      include Router

      get '/posts/:post_id' do |b|
        b.use Get
      end

      post '/posts' do
        use Create
      end
    end
  end
end
