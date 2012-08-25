require 'spec_helper'

describe TentServer::API::Posts do
  def app
    TentServer::API.new
  end

  describe 'GET /posts/:post_id' do
    it "should find existing post" do
      post = Fabricate(:post)
      post.save!
      json_get "/posts/#{post.id}"
      expect(last_response.body).to eq(post.to_json)
    end

    it "should be 404 if post_id doesn't exist" do
      json_get "/posts/invalid-id"
      expect(last_response.status).to eq(404)
    end
  end

  describe 'POST /posts' do
    it "should create post" do
      post = Fabricate(:post)
      post_attributes = post.as_json(:exclude => [:id])
      expect(lambda { json_post "/posts", post_attributes }).to change(TentServer::Model::Post, :count).by(1)
      expect(last_response.body).to eq(TentServer::Model::Post.last.to_json)
    end
  end
end
