require 'spec_helper'

describe TentServer::API::Posts do
  def app
    TentServer::API.new
  end

  describe 'GET /posts/:post_id' do
    it "should find existing post" do
      post = Fabricate(:post, :public => true)
      post.save!
      json_get "/posts/#{post.id}"
      expect(last_response.body).to eq(post.to_json)
    end

    it "should be 404 if post_id doesn't exist" do
      json_get "/posts/invalid-id"
      expect(last_response.status).to eq(404)
    end

    shared_examples "current_auth" do |options={}|
      context 'when post is not public' do
        let(:group) { Fabricate(:group, :name => 'friends') }
        let(:post) { Fabricate(:post, :public => false) }

        context 'when has explicit permission' do
          before do
            case current_auth
            when TentServer::Model::Follower
              current_auth.access_permissions.create(:post_id => post.id)
            else
              current_auth.permissions.create(:post_id => post.id)
            end
          end

          it 'should return post' do
            json_get "/posts/#{post.id}", nil, 'current_auth' => current_auth
            expect(last_response.status).to_not eq(404)
            expect(last_response.body).to eq(post.to_json)
          end
        end

        unless options[:groups] == false
          context 'when has permission via groups' do
            before do
              post.permissions.create(:group_id => group.id)
              current_auth.groups = [group.id]
              current_auth.save
            end

            it 'should return post' do
              json_get "/posts/#{post.id}", nil, 'current_auth' => current_auth
              expect(last_response.status).to_not eq(404)
              expect(last_response.body).to eq(post.to_json)
            end
          end
        end

        context 'when does not have permission' do
          it 'should return 404' do
            post # create post
            json_get "/posts/#{post.id}", nil, 'current_auth' => current_auth
            expect(last_response.status).to eq(404)
          end
        end
      end
    end

    context 'when Follower' do
      let(:current_auth) { Fabricate(:follower) }

      it_behaves_like "current_auth"
    end

    context 'when AppAuthorization' do
      let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

      it_behaves_like "current_auth"
    end

    context 'when App' do
      let(:current_auth) { Fabricate(:app) }

      it_behaves_like "current_auth", :groups => false
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
        json_get '/posts'
        expect(last_response.body).to eq(posts.to_json)
      end
    end

    it "should filter by params[:post_types]" do
      picture_type_uri = URI("https://tent.io/types/posts/picture")
      blog_type_uri = URI("https://tent.io/types/posts/blog")

      picture_post = Fabricate(:post)
      picture_post.type = picture_type_uri
      picture_post.save!
      non_picture_post = Fabricate(:post)
      non_picture_post.save!
      blog_post = Fabricate(:post)
      blog_post.type = blog_type_uri
      blog_post.save!

      posts = TentServer::Model::Post.all(:type => [picture_type_uri, blog_type_uri])
      post_types = [picture_post, blog_post].map { |p| URI.escape(p.type.to_s, "://") }

      json_get "/posts?post_types=#{post_types.join(',')}"
      expect(last_response.body).to eq(posts.to_json)
    end

    it "should filter by params[:since_id]" do
      since_post = Fabricate(:post)
      since_post.save!
      post = Fabricate(:post)
      post.save!

      json_get "/posts?since_id=#{since_post.id}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by params[:before_id]" do
      TentServer::Model::Post.all.destroy!
      post = Fabricate(:post)
      post.save!
      before_post = Fabricate(:post)
      before_post.save!

      json_get "/posts?before_id=#{before_post.id}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by both params[:since_id] and params[:before_id]" do
      since_post = Fabricate(:post)
      since_post.save!
      post = Fabricate(:post)
      post.save!
      before_post = Fabricate(:post)
      before_post.save!

      json_get "/posts?before_id=#{before_post.id}&since_id=#{since_post.id}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by params[:since_time]" do
      since_post = Fabricate(:post)
      since_post.published_at = Time.at(Time.now.to_i + 86400) # 1.day.from_now
      since_post.save!
      post = Fabricate(:post)
      post.published_at = Time.at(Time.now.to_i + (86400 * 2)) # 2.days.from_now
      post.save!

      json_get "/posts?since_time=#{since_post.published_at.to_time.to_i}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should filter by params[:before_time]" do
      post = Fabricate(:post)
      post.published_at = Time.at(Time.now.to_i - (86400 * 2)) # 2.days.ago
      post.save!
      before_post = Fabricate(:post)
      before_post.published_at = Time.at(Time.now.to_i - 86400) # 1.day.ago
      before_post.save!

      json_get "/posts?before_time=#{before_post.published_at.to_time.to_i}"
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

      json_get "/posts?before_time=#{before_post.published_at.to_time.to_i}&since_time=#{since_post.published_at.to_time.to_i}"
      expect(last_response.body).to eq([post].to_json)
    end

    it "should set feed length with params[:limit]" do
      0.upto(2).each { Fabricate(:post).save! }
      posts = TentServer::Model::Post.all(:limit => 1)
      json_get '/posts?limit=1'
      expect(last_response.body).to eq(posts.to_json)
    end

    it "limit should never exceed TentServer::API::MAX_PER_PAGE" do
      with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
        0.upto(2).each { Fabricate(:post).save! }
        json_get '/posts?limit=1'
        expect(last_response.body).to eq([].to_json)
      end
    end

    [:user, :server, :app].each do |type|
      it "should return exclude posts current_#{type} does not have permission"
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
