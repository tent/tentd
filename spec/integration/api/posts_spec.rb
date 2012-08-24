require 'spec_helper'

describe TentServer::API::Posts do
  def app
    TentServer::API
  end

  describe "GET /posts/:id" do
    it "finds existing post with given id" do
      post = Fabricate(:post)
      post.save
      json_get "/posts/#{post.id}"
      expect(last_response.body).to eq(post.to_json)
    end
  end

  describe "POST /posts" do

  end
end
