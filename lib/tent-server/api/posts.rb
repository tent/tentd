module TentServer
  class API
    class Posts < Grape::API
      get "/posts/:post_id" do
        Action::Posts.get(params)['response']
      end
    end
  end
end
