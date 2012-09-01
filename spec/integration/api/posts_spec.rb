require 'spec_helper'

describe TentServer::API::Posts do
  def app
    TentServer::API.new
  end

  def authorize!(*scopes)
    env['current_auth'] = stub(
      :kind_of? => true,
      :id => nil,
      :scopes => scopes
    )
  end

  let(:env) { Hash.new }
  let(:params) { Hash.new }

  describe 'GET /posts/:post_id' do
    using_permissions = proc do
      it "should find existing post by public_uid" do
        post = Fabricate(:post, :public => true)
        json_get "/posts/#{post.public_uid}"
        expect(last_response.body).to eq(post.to_json)
      end

      it "should not find existing post by actual id" do
        post = Fabricate(:post, :public => true)
        json_get "/posts/#{post.id}"
        expect(last_response.status).to eq(404)
      end

      it "should be 404 if post_id doesn't exist" do
        TentServer::Model::Post.all.destroy!
        json_get "/posts/1"
        expect(last_response.status).to eq(404)
      end

      shared_examples "current_auth" do
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
              json_get "/posts/#{post.public_uid}", nil, 'current_auth' => current_auth
              expect(last_response.status).to_not eq(404)
              expect(last_response.body).to eq(post.to_json)
            end
          end

          context 'when has permission via groups' do
            before do
              post.permissions.create(:group_id => group.id)
              current_auth.groups = [group.id]
              current_auth.save
            end

            it 'should return post' do
              json_get "/posts/#{post.public_uid}", nil, 'current_auth' => current_auth
              expect(last_response.status).to_not eq(404)
              expect(last_response.body).to eq(post.to_json)
            end
          end

          context 'when does not have permission' do
            it 'should return 404' do
              post # create post
              json_get "/posts/#{post.public_uid}", nil, 'current_auth' => current_auth
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
    end

    context 'without authorization', &using_permissions

    context 'with read_posts scope authorized' do
      before { authorize!(:read_posts) }

      context 'when post exists' do
        it 'should return post' do
          post = Fabricate(:post, :public => false)
          json_get "/posts/#{post.public_uid}", params, env
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq(post.to_json)
        end
      end

      context 'when no post exists with :id' do
        it 'should respond 404' do
          json_get "/posts/invalid-id", params, env
          expect(last_response.status).to eq(404)
        end
      end
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
    let(:post_public?) { true }
    with_params = proc do
      it "should respond with first TentServer::API::PER_PAGE posts if no params given" do
        with_constants "TentServer::API::PER_PAGE" => 1 do
          0.upto(TentServer::API::PER_PAGE+1).each { Fabricate(:post, :public => post_public?).save! }
          json_get '/posts', params, env
          expect(JSON.parse(last_response.body).size).to eq(1)
        end
      end

      it "should filter by params[:post_types]" do
        picture_type_uri = URI("https://tent.io/types/posts/picture")
        blog_type_uri = URI("https://tent.io/types/posts/blog")

        picture_post = Fabricate(:post, :public => post_public?)
        picture_post.type = picture_type_uri
        picture_post.save!
        non_picture_post = Fabricate(:post, :public => post_public?)
        non_picture_post.save!
        blog_post = Fabricate(:post, :public => post_public?)
        blog_post.type = blog_type_uri
        blog_post.save!

        posts = TentServer::Model::Post.all(:type => [picture_type_uri, blog_type_uri])
        post_types = [picture_post, blog_post].map { |p| URI.escape(p.type.to_s, "://") }

        json_get "/posts?post_types=#{post_types.join(',')}", params, env
        expect(last_response.body).to eq(posts.to_json)
      end

      it "should filter by params[:since_id]" do
        since_post = Fabricate(:post, :public => post_public?)
        since_post.save!
        post = Fabricate(:post, :public => post_public?)
        post.save!

        json_get "/posts?since_id=#{since_post.public_uid}", params, env
        expect(last_response.body).to eq([post].to_json)
      end

      it "should filter by params[:before_id]" do
        TentServer::Model::Post.all.destroy!
        post = Fabricate(:post, :public => post_public?)
        post.save!
        before_post = Fabricate(:post, :public => post_public?)
        before_post.save!

        json_get "/posts?before_id=#{before_post.public_uid}", params, env
        expect(last_response.body).to eq([post].to_json)
      end

      it "should filter by both params[:since_id] and params[:before_id]" do
        since_post = Fabricate(:post, :public => post_public?)
        since_post.save!
        post = Fabricate(:post, :public => post_public?)
        post.save!
        before_post = Fabricate(:post, :public => post_public?)
        before_post.save!

        json_get "/posts?before_id=#{before_post.public_uid}&since_id=#{since_post.public_uid}", params, env
        expect(last_response.body).to eq([post].to_json)
      end

      it "should filter by params[:since_time]" do
        since_post = Fabricate(:post, :public => post_public?)
        since_post.published_at = Time.at(Time.now.to_i + 86400) # 1.day.from_now
        since_post.save!
        post = Fabricate(:post, :public => post_public?)
        post.published_at = Time.at(Time.now.to_i + (86400 * 2)) # 2.days.from_now
        post.save!

        json_get "/posts?since_time=#{since_post.published_at.to_time.to_i}", params, env
        expect(last_response.body).to eq([post].to_json)
      end

      it "should filter by params[:before_time]" do
        post = Fabricate(:post, :public => post_public?)
        post.published_at = Time.at(Time.now.to_i - (86400 * 2)) # 2.days.ago
        post.save!
        before_post = Fabricate(:post, :public => post_public?)
        before_post.published_at = Time.at(Time.now.to_i - 86400) # 1.day.ago
        before_post.save!

        json_get "/posts?before_time=#{before_post.published_at.to_time.to_i}", params, env
        expect(last_response.body).to eq([post].to_json)
      end

      it "should filter by both params[:before_time] and params[:since_time]" do
        now = Time.at(Time.now.to_i - (86400 * 6)) # 6.days.ago
        since_post = Fabricate(:post, :public => post_public?)
        since_post.published_at = Time.at(now.to_i - (86400 * 3)) # 3.days.ago
        since_post.save!
        post = Fabricate(:post, :public => post_public?)
        post.published_at = Time.at(now.to_i - (86400 * 2)) # 2.days.ago
        post.save!
        before_post = Fabricate(:post, :public => post_public?)
        before_post.published_at = Time.at(now.to_i - 86400) # 1.day.ago
        before_post.save!

        json_get "/posts?before_time=#{before_post.published_at.to_time.to_i}&since_time=#{since_post.published_at.to_time.to_i}", params, env
        expect(last_response.body).to eq([post].to_json)
      end

      it "should set feed length with params[:limit]" do
        0.upto(2).each { Fabricate(:post, :public => post_public?).save! }
        json_get '/posts?limit=1', params, env
        expect(JSON.parse(last_response.body).size).to eq(1)
      end

      it "limit should never exceed TentServer::API::MAX_PER_PAGE" do
        with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
          0.upto(2).each { Fabricate(:post, :public => post_public?).save! }
          json_get '/posts?limit=1', params, env
          expect(last_response.body).to eq([].to_json)
        end
      end
    end

    context 'without authorization', &with_params

    context 'with read_posts scope authorized' do
      before { authorize!(:read_posts) }
      let(:post_public?) { false }

      context &with_params
    end
  end

  describe 'POST /posts' do
    context 'with write_posts scope authorized' do
      before { authorize!(:write_posts) }
      it "should create post" do
        post = Fabricate(:post)
        post_attributes = post.as_json(:exclude => [:id])
        expect(lambda { json_post "/posts", post_attributes, env }).to change(TentServer::Model::Post, :count).by(1)
        expect(last_response.body).to eq(TentServer::Model::Post.last.to_json)
      end
    end

    context 'without write_posts scope authorized' do
      it 'should respond 403' do
        expect(lambda { json_post "/posts", {}, env }).to_not change(TentServer::Model::Post, :count)
        expect(last_response.status).to eq(403)
      end
    end
  end
end
