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

    it "should filter by params[:since_id]" do
      since_post = Fabricate(:post)
      since_post.save!
      post = Fabricate(:post)
      post.save!

      get "/posts?since_id=#{since_post.id}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by params[:before_id]" do
      TentServer::Model::Post.all.each(&:destroy)
      post = Fabricate(:post)
      post.save!
      before_post = Fabricate(:post)
      before_post.save!

      get "/posts?before_id=#{before_post.id}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by both params[:since_id] and params[:before_id]" do
      since_post = Fabricate(:post)
      since_post.save!
      post = Fabricate(:post)
      post.save!
      before_post = Fabricate(:post)
      before_post.save!

      get "/posts?before_id=#{before_post.id}&since_id=#{since_post.id}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by params[:since_time]" do
      since_post = Fabricate(:post)
      since_post.published_at = Time.at(Time.now.to_i + 86400) # 1.day.from_now
      since_post.save!
      post = Fabricate(:post)
      post.published_at = Time.at(Time.now.to_i + (86400 * 2)) # 2.days.from_now
      post.save!

      get "/posts?since_time=#{since_post.published_at.to_time.to_i}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by params[:before_time]" do
      post = Fabricate(:post)
      post.published_at = Time.at(Time.now.to_i - (86400 * 2)) # 2.days.ago
      post.save!
      before_post = Fabricate(:post)
      before_post.published_at = Time.at(Time.now.to_i - 86400) # 1.day.ago
      before_post.save!

      get "/posts?before_time=#{before_post.published_at.to_time.to_i}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by both params[:before_time] and params[:since_time]" do
      now = Time.at(Time.now.to_i - (86400 * 6)) # 6.days.ago
      since_post = Fabricate(:post)
      since_post.published_at = Time.at(now.to_i - (86400 * 3)) # 3.days.ago
      since_post.save!
      post = Fabricate(:post)
      post.published_at = Time.at(now.to_i - (86400 * 2)) # 2.days.ago
      post.save!
      before_post = Fabricate(:post)
      before_post.published_at = Time.at(now.to_i - 86400) # 1.day.ago
      before_post.save!

      get "/posts?before_time=#{before_post.published_at.to_time.to_i}&since_time=#{since_post.published_at.to_time.to_i}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should set feed length with params[:limit]" do
      0.upto(2).each { Fabricate(:post).save! }
      posts = TentServer::Model::Post.all(:limit => 1)
      get '/posts?limit=1'
      expect(last_response.body).to eq(posts.to_json)
    end

    it "limit should never exceed TentServer::API::MAX_PER_PAGE" do
      with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
        0.upto(2).each { Fabricate(:post).save! }
        get '/posts?limit=1'
        expect(last_response.body).to eq([].to_json)
      end
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
