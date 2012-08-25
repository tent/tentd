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

  # Params:
  # - post_types
  # - since_id
  # - before_id
  # - since_time
  # - before_time
  # - limit
  describe 'GET /posts' do
    it "should respond with first TentServer::API::PER_PAGE posts if no params given" do
      with_constants "TentServer::API::PER_PAGE" => 1 do
        0.upto(TentServer::API::PER_PAGE+1).each { Fabricate(:post).save! }
        posts = TentServer::Model::Post.all(:limit => TentServer::API::PER_PAGE)
        get '/posts'
        expect(last_response.body).to eq(posts.to_json)
      end
    end

    it "should filter by params[:post_types]"

    it "should filter by params[:since_id]"

    it "should filter by params[:before_id]"

    it "should filter by params[:since_time]"

    it "should filter by params[:before_time]"

    it "should set max feed length with params[:limit]" do
      0.upto(2).each { Fabricate(:post).save! }
      posts = TentServer::Model::Post.all(:limit => 1)
      get '/posts?limit=1'
      expect(last_response.body).to eq(posts.to_json)
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
