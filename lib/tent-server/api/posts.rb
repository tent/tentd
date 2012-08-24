module TentServer
  class API
    class Posts < Grape::API
      get "/posts/:post_id" do
        Action.get_post(env)
      end
    end
  end
end
