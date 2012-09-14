require 'spec_helper'

describe TentD::API::Posts do
  def app
    TentD::API.new
  end

  let(:authorized_post_types) { [] }

  def authorize!(*scopes)
    options = scopes.last if scopes.last.kind_of?(Hash)
    scopes.delete(options)
    methods = {
      :kind_of? => true,
      :id => nil,
      :scopes => scopes,
      :post_types => authorized_post_types,
    }
    if options
      methods[:app] = options[:app] if options[:app]
      methods[:entity] = options[:entity] if options[:entity]
    end
    env['current_auth'] = stub(methods)
  end

  let(:env) { Hash.new }
  let(:params) { Hash.new }

  describe 'GET /posts/:post_id' do
    using_permissions = proc do
      not_authenticated = proc do
        it "should find existing post by public_id" do
          post = Fabricate(:post, :public => true)
          json_get "/posts/#{post.public_id}"
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['id']).to eq(post.public_id)
        end

        it "should not find existing post by actual id" do
          post = Fabricate(:post, :public => true)
          json_get "/posts/#{post.id}"
          expect(last_response.status).to eq(404)
        end

        it "should be 404 if post_id doesn't exist" do
          TentD::Model::Post.all.destroy!
          json_get "/posts/1"
          expect(last_response.status).to eq(404)
        end
      end

      context &not_authenticated

      shared_examples "current_auth" do
        context 'when post is not public' do
          let(:group) { Fabricate(:group, :name => 'friends') }
          let(:post) { Fabricate(:post, :public => false) }

          context 'when has explicit permission' do
            before do
              case current_auth
              when TentD::Model::Follower
                current_auth.access_permissions.create(:post_id => post.id)
              else
                current_auth.permissions.create(:post_id => post.id)
              end
            end

            it 'should return post' do
              json_get "/posts/#{post.public_id}", nil, 'current_auth' => current_auth
              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body)['id']).to eq(post.public_id)
            end
          end

          context 'when has permission via groups' do
            before do
              post.permissions.create(:group_public_id => group.public_id)
              current_auth.groups = [group.public_id]
              current_auth.save
            end

            it 'should return post' do
              json_get "/posts/#{post.public_id}", nil, 'current_auth' => current_auth
              expect(last_response.status).to eq(200)
              expect(JSON.parse(last_response.body)['id']).to eq(post.public_id)
            end
          end

          context 'when does not have permission' do
            it 'should return 404' do
              post # create post
              json_get "/posts/#{post.public_id}", nil, 'current_auth' => current_auth
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

        context &not_authenticated
      end
    end

    context 'without authorization', &using_permissions

    context 'with read_posts scope authorized' do
      before { authorize!(:read_posts) }
      let(:post_type) { 'https://tent.io/types/post/status' }

      post_type_authorized = proc do
        context 'when post exists' do
          it 'should return post' do
            post = Fabricate(:post, :public => false, :type_base => post_type)
            json_get "/posts/#{post.public_id}", params, env
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body)['id']).to eq(post.public_id)
          end
        end

        context 'when no post exists with :id' do
          it 'should respond 404' do
            json_get "/posts/invalid-id", params, env
            expect(last_response.status).to eq(404)
          end
        end
      end

      context 'when post type is authorized' do
        let(:authorized_post_types) { [post_type] }
        context &post_type_authorized
      end

      context 'when all post types authorized' do
        let(:authorized_post_types) { ['all'] }
        context &post_type_authorized
      end

      context 'when post type is not authorized' do
        it 'should return 404' do
          post = Fabricate(:post, :public => false, :type_base => post_type)
          json_get "/posts/#{post.public_id}", params, env
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
      it "should respond with first TentD::API::PER_PAGE posts if no params given" do
        with_constants "TentD::API::PER_PAGE" => 1 do
          0.upto(TentD::API::PER_PAGE+1).each { Fabricate(:post, :public => post_public?) }
          json_get '/posts', params, env
          expect(JSON.parse(last_response.body).size).to eq(1)
        end
      end

      it "should filter by params[:post_types]" do
        picture_type_uri = "https://tent.io/types/post/picture"
        blog_type_uri = "https://tent.io/types/post/blog"

        picture_post = Fabricate(:post, :public => post_public?, :type_base => picture_type_uri)
        non_picture_post = Fabricate(:post, :public => post_public?)
        blog_post = Fabricate(:post, :public => post_public?, :type_base => blog_type_uri)

        posts = TentD::Model::Post.all(:type_base => [picture_type_uri, blog_type_uri])
        post_types = [picture_post, blog_post].map { |p| URI.encode_www_form_component(p.type.base) }

        json_get "/posts?post_types=#{post_types.join(',')}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(posts.size)
        body_ids = body.map { |i| i['id'] }
        posts.each { |post|
          expect(body_ids).to include(post.public_id)
        }
      end

      it "should filter by params[:mentioned_post]" do
        mentioned_post = Fabricate(:post, :public => post_public?)
        post = Fabricate(:post, :public => post_public?, :mentions => [
          Fabricate(:mention, :mentioned_post_id => mentioned_post.public_id, :entity => mentioned_post.entity)
        ])

        json_get "/posts?mentioned_post=#{mentioned_post.public_id}&mentioned_entity=#{URI.encode_www_form_component(mentioned_post.entity)}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids).to include(post.public_id)
      end

      it "should filter by params[:entity]" do
        other_post = Fabricate(:post, :public => post_public?)
        first_post = Fabricate(:post, :public => post_public?, :entity => 'https://412doe.example.org')
        last_post  = Fabricate(:post, :public => post_public?, :entity => 'https://124alex.example.com')

        params[:entity] = [first_post.entity, last_post.entity]
        json_get "/posts", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(2)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids).to include(first_post.public_id)
        expect(body_ids).to include(last_post.public_id)
      end

      it "should order by published_at desc" do
        TentD::Model::Post.all.destroy
        first_post = Fabricate(:post, :public => post_public?, :published_at => Time.at(Time.now.to_i-86400)) # 1.day.ago
        latest_post = Fabricate(:post, :public => post_public?, :published_at => Time.at(Time.now.to_i+86400)) # 1.day.from_now

        json_get "/posts", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(2)
        expect(body.first['id']).to eq(latest_post.public_id)
        expect(body.last['id']).to eq(first_post.public_id)
      end

      it "should filter by params[:since_id]" do
        since_post = Fabricate(:post, :public => post_public?)
        post = Fabricate(:post, :public => post_public?)

        json_get "/posts?since_id=#{since_post.public_id}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should filter by params[:before_id]" do
        TentD::Model::Post.all.destroy
        post = Fabricate(:post, :public => post_public?)
        before_post = Fabricate(:post, :public => post_public?)

        json_get "/posts?before_id=#{before_post.public_id}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should filter by both params[:since_id] and params[:before_id]" do
        since_post = Fabricate(:post, :public => post_public?)
        post = Fabricate(:post, :public => post_public?)
        before_post = Fabricate(:post, :public => post_public?)

        json_get "/posts?before_id=#{before_post.public_id}&since_id=#{since_post.public_id}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should filter by params[:since_time]" do
        since_post = Fabricate(:post, :public => post_public?)
        since_post.published_at = Time.at(Time.now.to_i + 86400) # 1.day.from_now
        post = Fabricate(:post, :public => post_public?)
        post.published_at = Time.at(Time.now.to_i + (86400 * 2)) # 2.days.from_now
        post.save

        json_get "/posts?since_time=#{since_post.published_at.to_time.to_i}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should filter by params[:before_time]" do
        post = Fabricate(:post, :public => post_public?)
        post.published_at = Time.at(Time.now.to_i - (86400 * 2)) # 2.days.ago
        post.save
        before_post = Fabricate(:post, :public => post_public?)
        before_post.published_at = Time.at(Time.now.to_i - 86400) # 1.day.ago
        before_post.save

        json_get "/posts?before_time=#{before_post.published_at.to_time.to_i}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should filter by both params[:before_time] and params[:since_time]" do
        now = Time.at(Time.now.to_i - (86400 * 6)) # 6.days.ago
        since_post = Fabricate(:post, :public => post_public?)
        since_post.published_at = Time.at(now.to_i - (86400 * 3)) # 3.days.ago
        since_post.save
        post = Fabricate(:post, :public => post_public?)
        post.published_at = Time.at(now.to_i - (86400 * 2)) # 2.days.ago
        post.save
        before_post = Fabricate(:post, :public => post_public?)
        before_post.published_at = Time.at(now.to_i - 86400) # 1.day.ago
        before_post.save

        json_get "/posts?before_time=#{before_post.published_at.to_time.to_i}&since_time=#{since_post.published_at.to_time.to_i}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should set feed length with params[:limit]" do
        0.upto(2).each { Fabricate(:post, :public => post_public?) }
        json_get '/posts?limit=1', params, env
        expect(JSON.parse(last_response.body).size).to eq(1)
      end

      it "limit should never exceed TentD::API::MAX_PER_PAGE" do
        with_constants "TentD::API::MAX_PER_PAGE" => 0 do
          0.upto(2).each { Fabricate(:post, :public => post_public?) }
          json_get '/posts?limit=1', params, env
          expect(last_response.body).to eq([].to_json)
        end
      end
    end

    context 'without authorization', &with_params

    context 'with read_posts scope authorized' do
      before { authorize!(:read_posts) }
      let(:post_public?) { false }

      context 'when post type authorized' do
        let(:authorized_post_types) { ["https://tent.io/types/post/status", "https://tent.io/types/post/picture", "https://tent.io/types/post/blog"] }

        context &with_params
      end

      context 'when all post types authorized' do
        let(:authorized_post_types) { ['all'] }

        context &with_params
      end

      context 'when post type not authorized' do
        it 'should return empty array' do
          TentD::Model::Post.all.destroy
          post = Fabricate(:post, :public => false)
          json_get "/posts", params, env
          expect(last_response.body).to eq([].to_json)
        end
      end
    end
  end

  describe 'POST /posts' do
    let(:p) { Fabricate.build(:post) }

    context 'as app with write_posts scope authorized' do
      let(:application) { Fabricate.build(:app) }
      before { authorize!(:write_posts, :app => application) }

      it "should create post" do
        post_attributes = p.attributes
        post_attributes[:type] = p.type.uri
        expect(lambda {
          json_post "/posts", post_attributes, env
          expect(last_response.status).to eq(200)
        }).to change(TentD::Model::Post, :count).by(1)
        post = TentD::Model::Post.last
        expect(post.app_name).to eq(application.name)
        expect(post.app_url).to eq(application.url)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(post.public_id)
        expect(body['app']).to eq('url' => application.url, 'name' => application.name)
      end

      it 'should create post with mentions' do
        post_attributes = Hashie::Mash.new(p.attributes)
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        mentions = [
          { :entity => "https://johndoe.example.com" },
          { :entity => "https://alexsmith.example.org", :post => "post-uid" }
        ]
        post_attributes.merge!(
          :mentions => mentions
        )

        expect(lambda {
          json_post "/posts", post_attributes, env
          expect(last_response.status).to eq(200)
        }).to change(TentD::Model::Post, :count).by(1)

        post = TentD::Model::Post.last
        expect(post.as_json[:mentions]).to eq(mentions)
      end

      it 'should create post with permissions' do
        TentD::Model::Group.all.destroy
        TentD::Model::Follower.all.destroy
        TentD::Model::Following.all.destroy
        group = Fabricate(:group)
        follower = Fabricate(:follower, :entity => 'https://john321.example.org')
        following = Fabricate(:following, :entity => 'https://smith123.example.com')

        post_attributes = p.attributes
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        post_attributes.merge!(
          :permissions => {
            :public => false,
            :groups => [{ id: group.public_id }],
            :entities => {
              follower.entity => true,
              following.entity => true
            }
          }
        )

        expect(lambda {
          expect(lambda {
            json_post "/posts", post_attributes, env
            expect(last_response.status).to eq(200)
          }).to change(TentD::Model::Post, :count).by(1)
        }).to change(TentD::Model::Permission, :count).by(3)

        post = TentD::Model::Post.last
        expect(post.public).to be_false
      end

      it 'should create post with multipart attachments' do
        post_attributes = p.attributes
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        attachments = { :foo => [{ :filename => 'a', :content_type => 'text/plain', :content => 'asdf' },
                                 { :filename => 'a', :content_type => 'application/json', :content => 'asdf123' },
                                 { :filename => 'b', :content_type => 'text/plain', :content => '1234' }],
                        :bar => { :filename => 'bar.html', :content_type => 'text/html', :content => '54321' } }
        expect(lambda {
          expect(lambda {
            multipart_post('/posts', post_attributes, attachments, env)
          }).to change(TentD::Model::Post, :count).by(1)
        }).to change(TentD::Model::PostAttachment, :count).by(4)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(TentD::Model::Post.last.public_id)
      end
    end

    context 'without app write_posts scope authorized' do
      it 'should respond 403' do
        expect(lambda { json_post "/posts", {}, env }).to_not change(TentD::Model::Post, :count)
        expect(last_response.status).to eq(403)
      end
    end

    context 'as follower' do
      before { authorize!(:entity => 'https://smith.example.com') }

      it 'should allow a post from the follower' do
        post_attributes = p.attributes
        post_attributes[:id] = rand(36 ** 6).to_s(36)
        post_attributes[:type] = p.type.uri
        json_post "/posts", post_attributes, env
        body = JSON.parse(last_response.body)
        post = TentD::Model::Post.last
        expect(body['id']).to eq(post.public_id)
        expect(post.public_id).to eq(post_attributes[:id])
      end

      it "should not allow a post that isn't from the follower" do
        post_attributes = p.attributes
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        json_post "/posts", post_attributes.merge(:entity => 'example.org'), env
        expect(last_response.status).to eq(403)
      end
    end

    context 'as anonymous' do
      before { Fabricate(:following) }

      it 'should not allow a post by an entity that is a following' do
        post_attributes = p.attributes
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        json_post "/posts", post_attributes, env
        expect(last_response.status).to eq(403)
      end

      it 'should allow a post by an entity that is not a following' do
        post_attributes = p.attributes
        post_attributes[:id] = rand(36 ** 6).to_s(36)
        post_attributes[:type] = p.type.uri
        json_post "/posts", post_attributes.merge(:entity => 'example.org'), env
        body = JSON.parse(last_response.body)
        post = TentD::Model::Post.last
        expect(body['id']).to eq(post.public_id)
        expect(post.public_id).to eq(post_attributes[:id])
      end
    end
  end

  describe 'DELETE /posts/:post_id' do
    let(:post) { Fabricate(:post, :original => true) }

    context 'when authorized' do
      before { authorize!(:write_posts) }

      context 'when post exists' do
        it 'should delete post and create post deleted notification' do
          delete "/posts/#{post.public_id}", params, env
          expect(last_response.status).to eq(200)
          expect(TentD::Model::Post.first(:id => post.id)).to be_nil

          deleted_post = post
          post = TentD::Model::Post.last
          expect(post.content['id']).to eq(deleted_post.public_id)
          expect(post.type.base).to eq('https://tent.io/types/post/delete')
          expect(post.type_version).to eq('0.1.0')
        end
      end

      context 'when post is not original' do
        let(:post) { Fabricate(:post, :original => false) }

        it 'should return 403' do
          delete "/posts/#{post.public_id}", params, env
          expect(last_response.status).to eq(403)
        end
      end

      context 'when post does not exist' do
        it 'should return 404' do
          delete "/posts/post-id", params, env
          expect(last_response.status).to eq(404)
        end
      end
    end

    context 'when not authorized' do
      it 'should return 403' do
        delete "/posts/#{post.public_id}", params, env
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'GET /posts/:post_id/attachments/:attachment_name' do
    let(:post) { Fabricate(:post) }
    let(:attachment) { Fabricate(:post_attachment, :post => post) }

    it 'should get an attachment' do
      get "/posts/#{post.public_id}/attachments/#{attachment.name}", {}, 'HTTP_ACCEPT' => attachment.type
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq(attachment.type)
      expect(last_response.body).to eq('54321')
    end

    it "should 404 if the attachment doesn't exist" do
      get "/posts/#{post.public_id}/attachments/asdf"
      expect(last_response.status).to eq(404)
    end

    it "should 404 if the post doesn't exist" do
      get "/posts/asdf/attachments/asdf"
      expect(last_response.status).to eq(404)
    end
  end
end
