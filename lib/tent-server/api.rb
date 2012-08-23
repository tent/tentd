require 'grape'

module Tent
  module Server
    class API < Grape::API
      get "/posts/:post_id" do
        Action.get_post(env)
      end
    end
  end
end
