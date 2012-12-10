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
  let(:current_user) { TentD::Model::User.current }
  let(:other_user) { TentD::Model::User.create }
  let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }

  describe 'GET /notifications/:following_id' do
    context 'when following' do
      it 'should echo challange' do
        following = Fabricate(:following)
        params[:challenge] = '123'
        json_get "/notifications/#{following.public_id}", params, env
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(params[:challenge])
      end
    end

    context 'when not following' do
      it 'should return 404' do
        params[:challenge] = '123'
        json_get '/notifications/not-following-id', params, env
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end
    end

    context 'when another user following' do
      it 'should return 404' do
        following = Fabricate(:following, :user_id => other_user.id)
        params[:challenge] = '123'
        json_get "/notifications/#{following.public_id}", params, env
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end
    end
  end

  describe 'HEAD /posts' do
    it 'should return count of posts' do
      Fabricate(:post, :public => true, :user_id => other_user.id)
      Fabricate(:post, :public => true)
      Fabricate(:post, :public => true)
      Fabricate(:post, :public => false)

      with_constants "TentD::API::PER_PAGE" => 1 do
        head '/posts', params, env
        expect(last_response.status).to eq(200)
        expect(last_response.headers['Count']).to eql('2')
      end
    end

    context 'when read_posts scope authorized' do
      let(:authorized_post_types) { ['all'] }
      before { authorize!(:read_posts) }

      it 'should return count of posts' do
        Fabricate(:post, :public => true, :user_id => other_user.id)
        Fabricate(:post, :public => true)
        Fabricate(:post, :public => true)
        Fabricate(:post, :public => false)

        params[:limit] = 2
        head '/posts', params, env
        expect(last_response.status).to eq(200)
        expect(last_response.headers['Count']).to eql('3')
      end
    end
  end

  describe 'GET /posts/count' do
    it_should_get_count = proc do
      it 'should return count of posts' do
        post = Fabricate(:post, :public => true, :user_id => other_user.id)
        post = Fabricate(:post, :public => true)
        json_get '/posts/count', params, env
        expect(last_response.body).to eq(1.to_json)
      end

      it 'should return count of posts with type' do
        type = TentD::TentType.new("https://tent.io/types/post/example/v0.1.0")
        type2 = TentD::TentType.new("https://tent.io/types/post/blog/v0.1.0")
        post = Fabricate(:post, :public => true, :type_base => type.base, :type_version => type.version)
        post2 = Fabricate(:post, :public => true, :type_base => type.base, :type_version => type.version, :original => false)
        post3 = Fabricate(:post, :public => true, :type_base => type2.base, :type_version => type2.version)

        params[:post_types] = type.uri
        json_get '/posts/count', params, env
        expect(last_response.body).to eq(1.to_json)
      end
    end

    context &it_should_get_count

    context 'when read_posts scope authorized' do
      before { authorize!(:read_posts) }

      context &it_should_get_count

      context 'when specific types authorized' do
        let(:authorized_post_types) { %w(https://tent.io/types/post/example/v0.1.0 https://tent.io/types/post/blog/v0.1.0) }
        context &it_should_get_count
      end
    end
  end

  describe 'GET /posts/:post_id' do
    let(:env) { Hashie::Mash.new }
    let(:params) { Hashie::Mash.new }
    with_version = proc do
      context 'with params[:version] specified' do
        context 'when version exists' do
          it 'should return specified post version' do
            first_version = post.latest_version(:fields => [:version]).version
            post.update(:content => { 'text' => 'foo bar baz' })
            latest_version = post.latest_version(:fields => [:version]).version
            expect(first_version).to_not eq(latest_version)

            json_get "/posts/#{post.public_id}?version=#{first_version}", params, env
            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)
            expect(body['id']).to eq(post.public_id)
            expect(body['version']).to eq(first_version)

            json_get "/posts/#{post.public_id}?version=#{latest_version}", params, env
            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)
            expect(body['id']).to eq(post.public_id)
            expect(body['version']).to eq(latest_version)

            json_get "/posts/#{post.public_id}", params, env
            expect(last_response.status).to eq(200)
            body = JSON.parse(last_response.body)
            expect(body['id']).to eq(post.public_id)
            expect(body['version']).to eq(latest_version)
          end
        end

        context 'when version does not exist' do
          it 'should return 404' do
            json_get "/posts/#{post.public_id}?version=12", params, env
            expect(last_response.status).to eq(404)
            expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
          end
        end
      end
    end

    with_view = proc do
      context 'with params[:view] specified' do
        it 'should return post using specified view' do
          post.update(
            :views => {
              'mini' => {
                'content' => ['mini_text', 'title']
              }
            },
            :content => {
              'text' => 'The quick brown fox jumps over the lazy dog',
              'mini_text' => 'The quick brown fox...',
              'title' => 'Quick Fox'
            }
          )

          json_get "/posts/#{post.public_id}?view=mini", params, env
          expect(last_response.status).to eq(200)

          body = JSON.parse(last_response.body)
          expect(body['id']).to eq(post.public_id)
          expect(body['content']).to eq({
            'mini_text' => 'The quick brown fox...',
            'title' => 'Quick Fox'
          })
        end
      end
    end

    with_entity = proc do
      context 'with params[:entity]' do
        it 'should return post matching entity and post_id' do
          post_1 = Fabricate(:post, :entity => 'https://123smith.example.org')
          post_2 = Fabricate(:post, :entity => 'https://alex4567.example.com', :public_id => post_1.public_id)
          expect(post_1.public_id).to eq(post_2.public_id)

          json_get "/posts/#{URI.encode_www_form_component(post_2.entity)}/#{post_2.public_id}", params, env
          body = JSON.parse(last_response.body)
          expect(body['id']).to eq(post_2.public_id)
          expect(body['entity']).to eq(post_2.entity)
        end
      end

      context 'without params[:entity]' do
        it 'should return post matching current entity and post_id' do
          post_1 = Fabricate(:post, :entity => 'https://123smith.example.org')
          post_2 = Fabricate(:post, :entity => 'https://alex4567.example.com', :public_id => post_1.public_id)
          expect(post_1.public_id).to eq(post_2.public_id)

          env['tent.entity'] = post_1.entity

          json_get "/posts/#{post_1.public_id}", params, env
          body = JSON.parse(last_response.body)
          expect(body['id']).to eq(post_1.public_id)
          expect(body['entity']).to eq(post_1.entity)
        end
      end
    end

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
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end

        it "should not find post belonging to another user" do
          post = Fabricate(:post, :public => true, :user_id => other_user.id)
          json_get "/posts/#{post.public_id}"
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end

        it "should be 404 if post_id doesn't exist" do
          json_get "/posts/1"
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end
      end

      context &not_authenticated

      with_permissions = proc do
        it 'should return post' do
          json_get "/posts/#{post.public_id}", params, env
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body)['id']).to eq(post.public_id)
        end

        context &with_version
        context &with_view
        context &with_entity
      end

      current_auth_examples = proc do
        context 'when post is not public' do
          let(:group) { Fabricate(:group, :name => 'friends') }
          let(:post) { Fabricate(:post, :public => false) }

          context 'when has explicit permission' do
            before do
              case current_auth
              when TentD::Model::Follower
                TentD::Model::Permission.create(
                  :post_id => post.id,
                  :follower_access_id => current_auth.id
                )
              else
                TentD::Model::Permission.create(
                  :post_id => post.id,
                  current_auth.permissions_relationship_foreign_key => current_auth.id
                )
              end
              env.current_auth = current_auth
            end

            context &with_permissions
          end

          context 'when has permission via groups' do
            before do
              TentD::Model::Permission.create(
                :post_id => post.id,
                :group_public_id => group.public_id
              )
              current_auth.groups = [group.public_id]
              current_auth.save
              env.current_auth = current_auth
            end

            context &with_permissions
          end

          context 'when does not have permission' do
            it 'should return 404' do
              post # create post
              json_get "/posts/#{post.public_id}", params, env
              expect(last_response.status).to eq(404)
              expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
            end
          end
        end
      end

      context 'when Follower' do
        let(:current_auth) { Fabricate(:follower) }

        context &current_auth_examples
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
            expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
          end
        end
      end

      context 'when post type is authorized' do
        let(:authorized_post_types) { [post_type] }
        context &post_type_authorized
      end

      context 'when all post types authorized' do
        let(:authorized_post_types) { ['all'] }
        let(:post) { Fabricate(:post, :public => false) }

        context &post_type_authorized

        context &with_version
        context &with_view
        context &with_entity
      end

      context 'when post type is not authorized' do
        it 'should return 404' do
          post = Fabricate(:post, :public => false, :type_base => post_type)
          json_get "/posts/#{post.public_id}", params, env
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end
      end
    end
  end

  describe 'HEAD /posts/:post_id/versions' do
    count_header = proc do
      it 'should set COUNT header' do
        head "/posts/#{post.public_id}/versions", nil, env
        expect(last_response.headers['COUNT']).to eq(post.versions_dataset.count.to_s)
      end
    end

    context 'when post exists' do
      context 'when post is public' do
        let(:post) { Fabricate(:post, :public => true) }
        before { post.create_version! }

        context &count_header
      end

      context 'when post is private' do
        let(:post) { Fabricate(:post, :public => false) }

        context 'when authorized' do
          let!(:authorized_post_types) { ['all'] }
          before { authorize!(:read_posts) }

          context &count_header
        end

        context 'when not authorized' do
          it 'should set COUNT header to 0' do
            head "/posts/#{post.public_id}/versions", nil, env
            expect(last_response.headers['COUNT']).to eql('0')
          end
        end
      end
    end
  end

  describe 'GET /posts/:post_id/versions' do
    should_return_post_versions = proc do
      it 'should return post versions' do
        get "/posts/#{post.public_id}/versions", nil, env
        expect(last_response.status).to eq(200)
        expect(Yajl::Parser.parse(last_response.body).size).to eq(2)
      end

      context 'with params' do
        context '[:since_version]' do
          it 'should return versions > :since_version' do
            latest_post_version = post.create_version!

            params = { :since_version => post_version.version }
            get "/posts/#{post.public_id}/versions", params, env
            expect(last_response.status).to eql(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(1)
            expect(body.first['version']).to eql(latest_post_version.version)
          end
        end

        context '[:before_version]' do
          it 'should return versions < :before_version' do
            params = { :before_version => post_version.version }
            get "/posts/#{post.public_id}/versions", params, env
            expect(last_response.status).to eql(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(1)
            expect(body.first['version']).to eql(1)
          end
        end

        context '[:order] = asc' do
          it 'should return versions in asc order' do
            version_12 = Fabricate(:post_version, :post_id => post.id, :public_id => post.public_id, :version => 12)
            version_8  = Fabricate(:post_version, :post_id => post.id, :public_id => post.public_id, :version => 8)

            params = { :order => 'asc' }
            get "/posts/#{post.public_id}/versions", params, env
            expect(last_response.status).to eql(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(4)

            expect(body.map { |v| v['version'] }).to eql([1, 2, 8, 12])
          end
        end

        context '[:limit]' do
          context 'when :limit < MAX_PER_PAGE' do
            it 'should return :limit versions' do
              with_constants "TentD::API::MAX_PER_PAGE" => 10 do
                params = { :limit => 1 }
                get "/posts/#{post.public_id}/versions", params, env
                expect(last_response.status).to eql(200)

                body = Yajl::Parser.parse(last_response.body)
                expect(body.size).to eql(1)
              end
            end
          end

          context 'when :limit > MAX_PER_PAGE' do
            it 'should return MAX_PER_PAGE versions' do
              with_constants "TentD::API::MAX_PER_PAGE" => 1 do
                params = { :limit => 2 }
                get "/posts/#{post.public_id}/versions", params, env
                expect(last_response.status).to eql(200)

                body = Yajl::Parser.parse(last_response.body)
                expect(body.size).to eql(1)
              end
            end
          end
        end
      end

      it 'should order by version' do
        version_12 = Fabricate(:post_version, :post_id => post.id, :public_id => post.public_id, :version => 12)
        version_8  = Fabricate(:post_version, :post_id => post.id, :public_id => post.public_id, :version => 8)

        get "/posts/#{post.public_id}/versions", params, env
        expect(last_response.status).to eql(200)

        body = Yajl::Parser.parse(last_response.body)
        expect(body.size).to eql(4)

        expect(body.map { |v| v['version'] }).to eql([12, 8, 2, 1])
      end

      it 'should set pagination in link header' do
        expectation = lambda do |response|
          expect_pagination_header(response, {
            :path => "/posts/#{post.public_id}/versions",
            :next => {
              :before_version => "1"
            },
            :prev => {
              :since_version => "2"
            }
          })
        end

        with_constants "TentD::API::MAX_PER_PAGE" => 2 do
          get "/posts/#{post.public_id}/versions", params, env
          expect(last_response.status).to eql(200)
          expectation.call(last_response)

          head "/posts/#{post.public_id}/versions", params, env
          expect(last_response.status).to eql(200)
          expectation.call(last_response)
        end
      end

      context 'when on last page' do
        it 'should only set prev pagination in link header' do
          expectation = lambda do |response|
            expect_pagination_header(response, {
              :path => "/posts/#{post.public_id}/versions",
              :prev => {
                :since_version => "2"
              }
            })
          end

          params["since_version"] = 1

          with_constants "TentD::API::MAX_PER_PAGE" => 2 do
            get "/posts/#{post.public_id}/versions", params, env
            expect(last_response.status).to eql(200)
            expectation.call(last_response)

            head "/posts/#{post.public_id}/versions", params, env
            expect(last_response.status).to eql(200)
            expectation.call(last_response)
          end
        end
      end
    end

    should_not_return_post_versions = proc do
      it 'should not return post versions' do
        get "/posts/#{post.public_id}/versions", nil, env
        expect(last_response.status).to eq(200)
        expect(Yajl::Parser.parse(last_response.body)).to be_empty
      end
    end

    context 'when post exists' do
      context 'when post is public' do
        let!(:post) { Fabricate(:post, :public => true) }
        let!(:post_version) { post.create_version! }

        context &should_return_post_versions
      end

      context 'when post is private' do
        let!(:post) { Fabricate(:post, :public => false) }
        let!(:post_version) { post.create_version! }

        context 'when authorized' do
          let!(:authorized_post_types) { %w( all ) }
          before { authorize!(:read_posts) }

          context &should_return_post_versions
        end

        context 'when not authorized' do
          context &should_not_return_post_versions
        end
      end
    end

    context 'when post does not exist' do
      it 'should return 404' do
        get "/posts/invalid-id/versions"
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end
    end
  end

  describe 'GET/HEAD /posts/:post_id/mentions' do
    let(:post) { Fabricate(:post, :public => false) }

    let!(:known_mentioned_entity) { 'https://known.example.com' }
    let!(:known_mentioned_post) { Fabricate(:post, :public => true, :original => false, :entity => known_mentioned_entity) }
    let!(:known_mention) { Fabricate(:mention, :post_id => post.id, :mentioned_post_id => known_mentioned_post.public_id, :entity => known_mentioned_post.entity) }

    let(:known_private_mentioned_entity) { 'https://known_private.example.com' }
    let(:known_private_mentioned_post) { Fabricate(:post, :public => false, :original => false, :entity => known_private_mentioned_entity) }
    let(:known_private_mention) { Fabricate(:mention, :post_id => post.id, :original => false, :mentioned_post_id => known_private_mentioned_post.public_id, :entity => known_private_mentioned_post.entity) }

    let(:unknown_mentioned_entity) { 'https://unknown.example.com' }
    let(:unknown_mentioned_post) { Fabricate(:post, :public => true, :original => false, :entity => unknown_mentioned_entity, :user_id => other_user.id) }
    let(:unknown_mention) { Fabricate(:mention, :post_id => post.id, :mentioned_post_id => unknown_mentioned_post.public_id, :entity => unknown_mentioned_post.entity) }

    let(:other_known_mentioned_post_type) { 'https://tent.io/types/post/photo/v0.1.0' }
    let(:other_known_mentioned_entity) { 'https://other_known.example.com' }
    let(:other_known_mentioned_post) { Fabricate(:post, :public => true, :original => false, :entity => other_known_mentioned_entity, :type => other_known_mentioned_post_type) }
    let(:other_known_mention) { Fabricate(:mention, :post_id => post.id, :mentioned_post_id => other_known_mentioned_post.public_id, :entity => other_known_mentioned_post.entity) }

    context 'when authorized' do
      let(:authorized_post_types) { ['all'] }
      before { authorize!(:read_posts) }

      context 'with params' do
        context 'with [:before_id] param' do
          it 'should return mentions with id < :before_id' do
            other_known_mention # create

            params = {
              :before_id => other_known_mentioned_post.public_id
            }
            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(1)
            expect(body.first['post']).to eql(known_mentioned_post.public_id)
          end

          it 'should return mentions with id < :before_id where entity = :before_id_entity' do
            other_known_mention # create

            params = {
              :before_id => other_known_mentioned_post.public_id,
              :before_id_entity => other_known_mentioned_post.entity
            }
            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(1)
            expect(body.first['post']).to eql(known_mentioned_post.public_id)

            params = {
              :before_id => other_known_mentioned_post.public_id,
              :before_id_entity => post.entity
            }
            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(0)
          end
        end

        context 'with [:since_id] param' do
          it 'should return mentions with id > :since_id' do
            other_known_mention # create

            params = {
              :since_id => known_mentioned_post.public_id
            }
            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(1)
            expect(body.first['post']).to eql(other_known_mentioned_post.public_id)
          end

          it 'should return mentions with id > :since_id where entity = :since_id_entity' do
            other_known_mention # create

            params = {
              :since_id => known_mentioned_post.public_id,
              :since_id_entity => known_mentioned_post.entity
            }
            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(1)
            expect(body.first['post']).to eql(other_known_mentioned_post.public_id)

            params = {
              :since_id => known_mentioned_post.public_id,
              :since_id_entity => post.entity
            }
            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(0)
          end
        end

        context 'with [:limit] param' do
          it 'should return [:limit] mentions' do
            params = {
              :limit => 0
            }

            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(0)
          end
        end

        context 'with [:post_types] param' do
          it 'should only return mentions where mentioned post type matches :post_types' do
            other_known_mention # create

            params = {
              :post_types => other_known_mentioned_post_type
            }
            json_get "/posts/#{post.public_id}/mentions", params, env
            expect(last_response.status).to eq(200)

            body = Yajl::Parser.parse(last_response.body)
            expect(body.size).to eql(1)
            expect(body.first['post']).to eql(other_known_mentioned_post.public_id)
          end
        end
      end

      it 'should return mentions for :post_id' do
        json_get "/posts/#{post.public_id}/mentions", nil, env
        expect(last_response.status).to eq(200)

        body = Yajl::Parser.parse(last_response.body)
        expect(body.size).to eql(1)
        expect(body.first['entity']).to eql(known_mention.entity)
        expect(body.first['post']).to eql(known_mentioned_post.public_id)
        expect(body.first['type']).to eql(known_mentioned_post.type.uri)
      end

      it 'should set pagination in header' do
        other_known_mention # create

        with_constants "TentD::API::MAX_PER_PAGE" => 2 do
          json_get "/posts/#{post.public_id}/mentions", nil, env
          expect(last_response.status).to eq(200)

          mentions = post.public_mentions
          next_mention = mentions.last
          prev_mention = mentions.first
          expect_pagination_header(last_response, {
            :path => "/posts/#{post.public_id}/mentions",
            :next => {
              :before_id => next_mention.mentioned_post_id,
              :before_id_entity => next_mention.entity
            },
            :prev => {
              :since_id => prev_mention.mentioned_post_id,
              :since_id_entity => prev_mention.entity
            }
          })
        end
      end

      context 'when HEAD request' do
        it 'should return count header' do
          other_known_mention # create

          head "/posts/#{post.public_id}/mentions", nil, env
          expect(last_response.status).to eq(200)
          expect(last_response.headers['COUNT']).to eql("2")
        end
      end

      context 'when GET request' do
        it 'should not return count header' do
          get "/posts/#{post.public_id}/mentions", nil, env
          expect(last_response.status).to eq(200)
          expect(last_response.headers['COUNT']).to be_nil
        end
      end
    end

    context 'when not authorized' do
      it 'should return 404' do
        json_get "/posts/#{post.public_id}/mentions", nil, env
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end
    end
  end

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

      it "should only return posts for current user" do
        post = Fabricate(:post, :public => post_public?)
        other_post = Fabricate(:post, :public => post_public?, :user_id => other_user.id)
        json_get "/posts", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        expect(body.first['id']).to eq(post.public_id)
      end

      it "should filter by params[:post_types]" do
        picture_type = TentD::TentType.new("https://tent.io/types/post/picture/v0.1.0")
        blog_type = TentD::TentType.new("https://tent.io/types/post/blog/v0.1.0")

        picture_post = Fabricate(:post, :public => post_public?, :type_base => picture_type.base)
        non_picture_post = Fabricate(:post, :public => post_public?)
        blog_post = Fabricate(:post, :public => post_public?, :type_base => blog_type.base)

        posts = TentD::Model::Post.where(:type_base => [picture_type.base, blog_type.base]).all
        post_types = [picture_post, blog_post].map { |p| URI.encode_www_form_component(p.type.uri) }

        json_get "/posts?post_types=#{post_types.join(',')}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(posts.size)
        body_ids = body.map { |i| i['id'] }
        posts.each { |post|
          expect(body_ids).to include(post.public_id)
        }
      end

      context 'with params[:mentioned_post] and/or params[:mentioned_entity]' do
        it "should return post matching both mentioned post and entity" do
          mentioned_post = Fabricate(:post, :public => post_public?)
          post = Fabricate(:post, :public => post_public?)
          Fabricate(:mention,
                    :post_id => post.id,
                    :mentioned_post_id => mentioned_post.public_id,
                    :entity => mentioned_post.entity)

          json_get "/posts?mentioned_post=#{mentioned_post.public_id}&mentioned_entity=#{URI.encode_www_form_component(mentioned_post.entity)}", params, env
          body = JSON.parse(last_response.body)
          expect(body.size).to eq(1)
          body_ids = body.map { |i| i['id'] }
          expect(body_ids).to include(post.public_id)
        end

        it "should return empty array if mentioned post doesn't match" do
          json_get "/posts?mentioned_post=invalid-post-id-127", {}, env
          body = JSON.parse(last_response.body)
          expect(body.size).to eq(0)
        end
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

      it "should order by received_at desc" do
        first_post = Fabricate(:post, :public => post_public?, :received_at => Time.at(Time.now.to_i-86400)) # 1.day.ago
        latest_post = Fabricate(:post, :public => post_public?, :received_at => Time.at(Time.now.to_i+86400)) # 1.day.from_now

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

      it "should return an empty array when since_id doesn't exist" do
        some_post = Fabricate(:post, :public => post_public?)

        json_get "/posts?since_id=invalid-id", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(0)
      end

      it "should filter by params[:before_id]" do
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
        since_post.received_at = Time.at(Time.now.to_i + 86400) # 1.day.from_now
        post = Fabricate(:post, :public => post_public?)
        post.received_at = Time.at(Time.now.to_i + (86400 * 2)) # 2.days.from_now
        post.save

        json_get "/posts?since_time=#{since_post.received_at.to_time.to_i}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should filter by params[:before_time]" do
        post = Fabricate(:post, :public => post_public?)
        post.received_at = Time.at(Time.now.to_i - (86400 * 2)) # 2.days.ago
        post.save
        before_post = Fabricate(:post, :public => post_public?)
        before_post.received_at = Time.at(Time.now.to_i - 86400) # 1.day.ago
        before_post.save

        json_get "/posts?before_time=#{before_post.received_at.to_time.to_i}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      it "should filter by both params[:before_time] and params[:since_time]" do
        now = Time.at(Time.now.to_i - (86400 * 6)) # 6.days.ago
        since_post = Fabricate(:post, :public => post_public?)
        since_post.received_at = Time.at(now.to_i - (86400 * 3)) # 3.days.ago
        since_post.save
        post = Fabricate(:post, :public => post_public?)
        post.received_at = Time.at(now.to_i - (86400 * 2)) # 2.days.ago
        post.save
        before_post = Fabricate(:post, :public => post_public?)
        before_post.received_at = Time.at(now.to_i - 86400) # 1.day.ago
        before_post.save

        json_get "/posts?before_time=#{before_post.received_at.to_time.to_i}&since_time=#{since_post.received_at.to_time.to_i}", params, env
        body = JSON.parse(last_response.body)
        expect(body.size).to eq(1)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.first).to eq(post.public_id)
      end

      context "when params[:sort_by] = 'updated_at'" do
        it "should order by updated_at desc" do
          post = Fabricate(:post, :public => post_public?)

          a_day_ago = Time.at(Time.now.to_i - 86400)
          Time.stubs(:now).returns(a_day_ago)
          earlier_post = Fabricate(:post, :public => post_public?)

          expect(earlier_post.updated_at < post.updated_at).to be_true

          json_get "/posts", { :sort_by => 'updated_at' }, env
          body = JSON.parse(last_response.body)
          expect(body.size).to eq(2)
          body_ids = body.map { |i| i['id'] }
          expect(body_ids.first).to eq(post.public_id)
        end

        context "when params[:order] = 'asc'" do
          it "should order by updated_at asc" do
            post = Fabricate(:post, :public => post_public?)

            a_day_ago = Time.at(Time.now.to_i - 86400)
            Time.stubs(:now).returns(a_day_ago.to_s)
            earlier_post = Fabricate(:post, :public => post_public?)

            expect(earlier_post.updated_at < post.updated_at).to be_true

            json_get "/posts", { :sort_by => 'updated_at', :order => 'asc' }, env
            body = JSON.parse(last_response.body)
            expect(body.size).to eq(2)
            body_ids = body.map { |i| i['id'] }
            expect(body_ids.first).to eq(earlier_post.public_id)
          end

          it "should paginate" do
            post = Fabricate(:post, :public => post_public?)

            a_day_ago = Time.at(Time.now.to_i - 86400)
            Time.stubs(:now).returns(a_day_ago.to_s)
            earlier_post = Fabricate(:post, :public => post_public?)

            expect(earlier_post.updated_at < post.updated_at).to be_true

            with_constants "TentD::API::MAX_PER_PAGE" => 1 do
              params = {
                :sort_by => 'updated_at',
                :order => 'asc',
                :since_id => earlier_post.public_id,
                :since_id_entity => earlier_post.entity
              }
              json_get "/posts", params, env
              body = JSON.parse(last_response.body)
              expect(body.size).to eq(1)
              body_ids = body.map { |i| i['id'] }
              expect(body_ids.first).to eq(post.public_id)
            end
          end

          it "should set pagination in header" do
            post = Fabricate(:post, :public => post_public?)

            a_day_ago = Time.at(Time.now.to_i - 86400)
            Time.stubs(:now).returns(a_day_ago.to_s)
            earlier_post = Fabricate(:post, :public => post_public?)

            expect(earlier_post.updated_at < post.updated_at).to be_true

            with_constants "TentD::API::MAX_PER_PAGE" => 2 do
              params = { :sort_by => 'updated_at', :order => 'asc' }
              json_get "/posts", params, env
              expect_pagination_header(last_response, {
                :path => '/posts',
                :next => params.merge(
                  :since_id => post.public_id,
                  :since_id_entity => post.entity
                ),
                :prev => params.merge(
                  :before_id => earlier_post.public_id,
                  :before_id_entity => earlier_post.entity
                )
              })
            end
          end
        end
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

      it "should set pagination in header" do
        post1 = Fabricate(:post, :public => post_public?)
        post2 = Fabricate(:post, :public => post_public?)

        with_constants "TentD::API::MAX_PER_PAGE" => 2 do
          json_get "/posts", params, env
          expect_pagination_header(last_response, {
            :path => '/posts',
            :next => {
              :before_id => post1.public_id,
              :before_id_entity => post1.entity
            },
            :prev => {
              :since_id => post2.public_id,
              :since_id_entity => post2.entity
            }
          })

          head "/posts", params, env
          expect_pagination_header(last_response, {
            :path => '/posts',
            :next => {
              :before_id => post1.public_id,
              :before_id_entity => post1.entity
            },
            :prev => {
              :since_id => post2.public_id,
              :since_id_entity => post2.entity
            }
          })
        end
      end
    end

    context 'without authorization', &with_params

    context 'with read_posts scope authorized' do
      before { authorize!(:read_posts) }
      let(:post_public?) { false }

      context 'when post type authorized' do
        let(:authorized_post_types) { ["https://tent.io/types/post/status/v0.1.0", "https://tent.io/types/post/picture/v0.1.0", "https://tent.io/types/post/blog/v0.1.0"] }

        context &with_params
      end

      context 'when all post types authorized' do
        let(:authorized_post_types) { ['all'] }

        context &with_params
      end

      context 'when post type not authorized' do
        let(:authorized_post_types) { %w(https://tent.io/types/post/status/v0.1.0) }
        it 'should return empty array' do
          post = Fabricate(:post, :public => false, :type_base => 'https://tent.io/types/post/repost', :type_version => '0.1.0')
          json_get "/posts", params, env
          expect(last_response.body).to eq([].to_json)
        end
      end
    end
  end

  describe 'POST /posts' do
    let(:p) { Fabricate.build(:post) }

    context 'as app with import_posts scope authorized' do
      let(:application) { Fabricate.build(:app) }
      let(:following) { Fabricate(:following) }
      before { authorize!(:import_posts, :app => application) }

      it "should create post" do
        post_attributes = p.attributes
        post_attributes[:type] = p.type.uri
        post_attributes[:following_id] = following.public_id
        expect(lambda {
          expect(lambda {
            json_post "/posts", post_attributes, env
            expect(last_response.status).to eq(200)
          }).to change(TentD::Model::Post, :count).by(1)
        }).to change(TentD::Model::PostVersion, :count).by(1)
        post = TentD::Model::Post.order(:id.asc).last
        expect(post.app_name).to eq(application.name)
        expect(post.app_url).to eq(application.url)
        expect(post.user_id).to eq(current_user.id)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(post.public_id)
        expect(body['app']).to eq('url' => application.url, 'name' => application.name)
      end
    end

    context 'as app with write_posts scope authorized' do
      let(:application) { Fabricate.build(:app) }
      before { authorize!(:write_posts, :app => application) }

      it "should create post" do
        post_attributes = p.attributes
        post_attributes[:type] = p.type.uri
        expect(lambda {
          expect(lambda {
            json_post "/posts", post_attributes, env
            expect(last_response.status).to eq(200)
          }).to change(TentD::Model::Post, :count).by(1)
        }).to change(TentD::Model::PostVersion, :count).by(1)
        post = TentD::Model::Post.order(:id.asc).last
        expect(post.app_name).to eq(application.name)
        expect(post.app_url).to eq(application.url)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(post.public_id)
        expect(body['app']).to eq('url' => application.url, 'name' => application.name)
      end

      it 'should create post with views' do
        post_attributes = p.attributes
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        post_attributes[:views] = {
          'mini' => {
            'content' => ['mini_text', 'title']
          }
        }

        expect(lambda {
          expect(lambda {
            json_post "/posts", post_attributes, env
            expect(last_response.status).to eq(200)
          }).to change(TentD::Model::Post, :count).by(1)
        }).to change(TentD::Model::PostVersion, :count).by(1)
        post = TentD::Model::Post.order(:id.asc).last

        expect(post.views).to eq(post_attributes[:views])
      end

      it 'should create post with mentions' do
        post_attributes = Hashie::Mash.new(p.attributes)
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        mentions = [
          { :entity => "https://johndoe.example.com" },
          { :entity => "https://johndoe.example.com" },
          { :entity => "https://alexsmith.example.org", :post => "post-uid" }
        ]
        post_attributes.merge!(
          :mentions => mentions
        )

        expect(lambda {
          expect(lambda {
            json_post "/posts", post_attributes, env
            expect(last_response.status).to eq(200)
          }).to change(TentD::Model::Post, :count).by(1)
        }).to change(TentD::Model::Mention, :count).by(2)

        post = TentD::Model::Post.order(:id.asc).last
        mentions.uniq!
        expect(post.as_json[:mentions].sort_by { |m| m[:entity] }).to eq(mentions.sort_by { |m| m[:entity] })
        expect(post.mentions.map(&:id).sort).to eq(post.latest_version.mentions.map(&:id).sort)
      end

      it 'should create post with permissions' do
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

        post = TentD::Model::Post.order(:id.asc).last
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
            expect(lambda {
              multipart_post('/posts', post_attributes, attachments, env)
            }).to change(TentD::Model::Post, :count).by(1)
          }).to change(TentD::Model::PostVersion, :count).by(1)
        }).to change(TentD::Model::PostAttachment, :count).by(4)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(TentD::Model::Post.order(:id.asc).last.public_id)

        post = TentD::Model::Post.order(:id.asc).last
        expect(post.attachments.map(&:id)).to eq(post.latest_version.attachments.map(&:id))
      end
    end

    context 'without app write_posts scope authorized' do
      it 'should respond 403' do
        expect(lambda { json_post "/posts", {}, env }).to_not change(TentD::Model::Post, :count)
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end
    end

    context 'as follower' do
      before { authorize!(:entity => 'https://smith.example.com') }
      let(:post_attributes) {
        p.attributes.merge(:id => rand(36 ** 6).to_s(36), :type => p.type.uri)
      }

      it 'should allow a post from the follower' do
        json_post "/posts", post_attributes, env
        body = JSON.parse(last_response.body)
        post = TentD::Model::Post.order(:id.asc).last
        expect(body['id']).to eq(post.public_id)
        expect(post.public_id).to eq(post_attributes[:id])
      end

      it "should silently allow a duplicate post from a follower" do
        json_post "/posts", post_attributes, env
        expect(last_response.status).to eq(200)
        json_post "/posts", post_attributes, env
        expect(last_response.status).to eq(200)
      end

      it "should not allow a post that isn't from the follower" do
        post_attributes = p.attributes
        post_attributes.delete(:id)
        post_attributes[:type] = p.type.uri
        json_post "/posts", post_attributes.merge(:entity => 'example.org'), env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end

      it "should notify subscribed apps of post" do
        following = Fabricate(:following)
        env['current_auth'] = following
        TentD::Notifications.expects(:trigger)

        json_post "/notifications/#{following.public_id}", post_attributes, env
        expect(last_response.status).to eql(200)
      end

      describe 'profile update post' do
        let(:following) { Fabricate(:following) }
        let(:post_attributes) {
          {
            :type => 'https://tent.io/types/post/profile/v0.1.0',
            :entity => following.entity,
            :content => {
              :action => 'update',
              :types => ['https://tent.io/types/info/core/v0.1.0'],
            }
          }
        }

        it "should trigger a profile update" do
          env['current_auth'] = following
          TentD::Notifications.expects(:update_following_profile).with(:following_id => following.id)
          json_post "/notifications/#{following.public_id}", post_attributes, env
          expect(last_response.status).to eq(200)
        end

        context 'follower profile update post' do
          let(:follower) { Fabricate(:follower) }

          let(:post_attributes) {
            {
              :type => 'https://tent.io/types/post/profile/v0.1.0',
              :entity => follower.entity,
              :content => {
                :action => 'update',
                :types => ['https://tent.io/types/info/core/v0.1.0'],
              }
            }
          }

          it 'should trigger a entity update' do
            env['current_auth'] = follower
            TentD::Model::Follower.expects(:update_entity).with(follower.id)
            json_post "/posts", post_attributes, env
            expect(last_response.status).to eq(200)
          end
        end
      end

      describe 'delete post' do
        let(:following) { Fabricate(:following) }
        let(:p) { Fabricate(:post, :entity => following.entity, :following => following, :original => false) }
        let(:post_attributes) {
          {
            :type => 'https://tent.io/types/post/delete/v0.1.0',
            :entity => following.entity,
            :content => {
              :id => p.public_id
            }
          }
        }

        it "should trigger a post deletion" do
          env['current_auth'] = following
          json_post "/notifications/#{following.public_id}", post_attributes, env
          expect(last_response.status).to eq(200)
          expect(TentD::Model::Post.first(:id => p.id)).to be_nil
        end

        it "should not trigger a post deletion for another user" do
          env['current_auth'] = following
          p.update(:user_id => other_user.id)
          json_post "/notifications/#{following.public_id}", post_attributes, env
          expect(TentD::Model::Post.first(:id => p.id)).to_not be_nil
          expect(last_response.status).to eq(200)
        end
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
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end

      it 'should allow a post by an entity that is not a following' do
        post_attributes = p.attributes
        post_attributes[:id] = rand(36 ** 6).to_s(36)
        post_attributes[:type] = p.type.uri
        json_post "/posts", post_attributes.merge(:entity => 'example.org'), env
        body = JSON.parse(last_response.body)
        post = TentD::Model::Post.order(:id.asc).last
        expect(body['id']).to eq(post.public_id)
        expect(post.public_id).to eq(post_attributes[:id])
        expect(post.user_id).to eq(current_user.id)
      end

      it 'should not allow posting as the entity' do
        post_attributes = p.attributes
        post_attributes[:id] = rand(36 ** 6).to_s(36)
        post_attributes[:type] = p.type.uri
        json_post "/posts", post_attributes.merge(:entity => 'https://example.org'), env.merge('tent.entity' => 'https://example.org')
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end

      context 'when following belongs to another user' do
        it 'should allow post by entity' do
          entity = 'https://other.example.com'
          following = Fabricate(:following, :entity => entity, :user_id => other_user.id)

          post_attributes = p.attributes
          post_attributes[:id] = rand(36 ** 6).to_s(36)
          post_attributes[:type] = p.type.uri
          json_post "/posts", post_attributes.merge(:entity => entity), env
          expect(last_response.status).to eq(200)
          body = JSON.parse(last_response.body)
          post = TentD::Model::Post.order(:id.asc).last
          expect(body['id']).to eq(post.public_id)
          expect(post.public_id).to eq(post_attributes[:id])
          expect(post.user_id).to eq(current_user.id)
        end
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

          deleted_post = TentD::Model::Post.unfiltered.first(:id => post.id)
          expect(deleted_post).to_not be_nil
          expect(deleted_post.deleted_at).to_not be_nil

          deleted_post = post
          post = TentD::Model::Post.order(:id.asc).last
          expect(post.content['id']).to eq(deleted_post.public_id)
          expect(post.type.base).to eq('https://tent.io/types/post/delete')
          expect(post.type_version).to eq('0.1.0')
        end

        context 'when post has mentions' do
          let!(:mention) { Fabricate(:mention, :entity => 'https://example.local', :post_id => post.id) }

          it 'should send delete post notification to mentions' do
            TentD::Notifications.expects(:notify_entity).with { |msg|
              msg[:entity] == mention.entity && msg[:post_id] != post.id
            }

            delete "/posts/#{post.public_id}", params, env
            expect(last_response.status).to eq(200)
          end
        end
      end

      context 'when post belongs to another user' do
        let!(:post) { Fabricate(:post, :original => true, :user_id => other_user.id) }

        it 'should return 404' do
          expect(lambda {
            delete "/posts/#{post.public_id}", params, env
            expect(last_response.status).to eq(404)
            expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
          }).to_not change(TentD::Model::Post, :count)
        end
      end

      context 'when post is not original' do
        let(:post) { Fabricate(:post, :original => false) }

        it 'should return 403' do
          delete "/posts/#{post.public_id}", params, env
          expect(last_response.status).to eq(403)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
        end
      end

      context 'when post does not exist' do
        it 'should return 404' do
          delete "/posts/post-id", params, env
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end
      end
    end

    context 'when not authorized' do
      it 'should return 403' do
        delete "/posts/#{post.public_id}", params, env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
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

    context 'with params[:version]' do
      it 'should get specified version of attachment' do
        post_version = Fabricate(:post_version, :post => post, :public_id => post.public_id, :version => 12)
        new_attachment = Fabricate(:post_attachment, :post => nil, :data => Base64.encode64('ChunkyBacon'))
        new_attachment.db[:post_versions_attachments].insert(:post_version_id => post_version.id, :post_attachment_id => new_attachment.id)

        expect(post.latest_version(:fields => [:id]).id).to eq(post_version.id)
        expect(new_attachment.name).to eq(attachment.name)

        get "/posts/#{post.public_id}/attachments/#{attachment.name}", { :version => post_version.version}, 'HTTP_ACCEPT' => attachment.type

        expect(last_response.status).to eq(200)
        expect(last_response.headers['Content-Type']).to eq(attachment.type)
        expect(last_response.body).to eq('ChunkyBacon')
      end

      it "should return 404 if specified version doesn't exist" do
        get "/posts/#{post.public_id}/attachments/#{attachment.name}", { :version => 20}, 'HTTP_ACCEPT' => attachment.type
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end

      context 'when :post_id is not original' do
        let(:authorized_post_types) { ['all'] }
        before {
          TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
          authorize!(:read_posts)
        }

        context 'when following post author' do
          let!(:following) { Fabricate(:following) }
          let!(:attachment) { Fabricate(:post_attachment) }

          context 'when :post_id exists' do
            let!(:post) { Fabricate(:post, :following_id => following.id, :original => false) }

            context 'when attachment exists' do
              it 'should get attachment via proxy' do
                http_stubs.get("/posts/#{post.public_id}/attachments/foo") { |env|
                  expect(env[:request_headers]['Authorization']).to match(/#{following.mac_key_id}/)
                  [200, {  'Content-Type' => attachment.type }, [Base64.decode64(attachment.data)]]
                }
                json_get("/posts/#{post.public_id}/attachments/foo", {}, env)
                expect(last_response.status).to eql(200)
                expect(last_response.body).to eql(Base64.decode64(attachment.data))
                expect(last_response.headers['Content-Type']).to eq(attachment.type)
                http_stubs.verify_stubbed_calls
              end
            end

            context 'when attachment does not exist' do
              it 'should proxy response' do
                http_stubs.get("/posts/#{post.public_id}/attachments/foo") { |env|
                  expect(env[:request_headers]['Authorization']).to match(/#{following.mac_key_id}/)
                  [404, {}, []]
                }
                json_get("/posts/#{post.public_id}/attachments/foo", {}, env)
                expect(last_response.status).to eql(404)
                http_stubs.verify_stubbed_calls
              end
            end
          end

          it 'should return 404 if post_id does not exist' do
            json_get("/posts/post-id/attachments/foo", {}, env)
            expect(last_response.status).to eql(404)
            expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
          end
        end

        context 'when not following post author' do
          let!(:post) { Fabricate(:post, :original => false) }

          it 'should return 404' do
            json_get("/posts/#{post.public_id}/attachments/foo", {}, env)
            expect(last_response.status).to eql(404)
            expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
          end
        end
      end
    end

    it "should 404 if the attachment doesn't exist" do
      get "/posts/#{post.public_id}/attachments/asdf"
      expect(last_response.status).to eq(404)
      expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
    end

    it "should 404 if the post doesn't exist" do
      get "/posts/asdf/attachments/asdf"
      expect(last_response.status).to eq(404)
      expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
    end

    context 'when post belongs to another user' do
      let(:post) { Fabricate(:post, :user_id => other_user.id) }

      it 'should return 404' do
        get "/posts/#{post.public_id}/attachments/#{attachment.name}", {}, 'HTTP_ACCEPT' => attachment.type
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end
    end
  end

  describe 'PUT /posts/:post_id' do
    let(:post) { Fabricate(:post) }

    context 'when authorized' do
      before { authorize!(:write_posts) }

      context 'when post belongs to another user' do
        let(:post) { Fabricate(:post, :user_id => other_user.id) }

        it 'should return 404' do
          post_attributes = {
            :content => {
              "text" => "Foo Bar Baz"
            }
          }
          json_put "/posts/#{post.public_id}", post_attributes, env
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end
      end

      it 'should update post' do
        Fabricate(:post_attachment, :post => post)
        Fabricate(:mention, :post => post)

        post_attributes = {
          :content => {
            "text" => "Foo Bar Baz"
          },
          :views => {
            'mini' => { 'content' => ['mini_text'] }
          },
          :entity => "#{post.entity}/foo/bar",
          :public => !post.public,
          :licenses => post.licenses.to_a + ['https://license.example.org']
        }

        expect(lambda {
          expect(lambda {
            expect(lambda {
              json_put "/posts/#{post.public_id}", post_attributes, env
              expect(last_response.status).to eq(200)

              post.reload
              expect(post.content).to eq(post_attributes[:content])
              expect(post.licenses).to eq(post_attributes[:licenses])
              expect(post.views).to eq(post_attributes[:views])
              expect(post.public).to_not eq(post_attributes[:public])
              expect(post.entity).to_not eq(post_attributes[:entity])
            }).to change(post.versions_dataset, :count).by(1)
          }).to change(post.mentions_dataset, :count).by(-1)
        }).to_not change(post.attachments_dataset, :count)
      end

      it 'should update mentions' do
        existing_mentions = 2.times.map { Fabricate(:mention, :post => post) }
        post_attributes = {
          :mentions => [
            { :entity => "https://johndoe.example.com" },
            { :entity => "https://alexsmith.example.org", :post => "post-uid" }
          ]
        }

        expect(lambda {
          expect(lambda {
            json_put "/posts/#{post.public_id}", post_attributes, env
            expect(last_response.status).to eq(200)

            existing_mentions.each do |m|
              m.reload
              expect(m.post_versions_dataset.count).to eql(1)
              expect(m.post_id).to be_nil
            end
          }).to change(TentD::Model::Mention, :count).by(2)
        }).to change(post.versions_dataset, :count).by(1)
      end

      it 'should update attachments' do
        existing_attachments = 2.times.map { Fabricate(:post_attachment, :post => post) }
        attachments = { :foo => [{ :filename => 'a', :content_type => 'text/plain', :content => 'asdf' },
                                 { :filename => 'a', :content_type => 'application/json', :content => 'asdf123' },
                                 { :filename => 'b', :content_type => 'text/plain', :content => '1234' }],
                        :bar => { :filename => 'bar.html', :content_type => 'text/html', :content => '54321' } }

        last_version = post.latest_version

        expect(lambda {
          expect(lambda {
            expect(lambda {
              multipart_put("/posts/#{post.public_id}", {}, attachments, env)
              expect(last_response.status).to eq(200)

              existing_attachments.each do |a|
                a.reload
                expect(a.post_versions_dataset.count).to eql(1)
                expect(a.post_id).to be_nil
              end
            }).to change(TentD::Model::Post, :count).by(0)
          }).to change(TentD::Model::PostVersion, :count).by(1)
        }).to change(TentD::Model::PostAttachment, :count).by(4)

        post.reload
        expect(post.attachments.map(&:id)).to eq(post.latest_version.attachments.map(&:id))

        expect(last_version.attachments.map(&:id)).to eql(existing_attachments.map(&:id))
      end

      it 'should update post version' do
        existing_version = post.create_version!
        existing_version_attachments = 2.times.map { Fabricate(:post_attachment) }.each do |a|
          existing_version.db[:post_versions_attachments].insert(
            :post_attachment_id => a.id,
            :post_version_id => existing_version.id
          )
        end
        existing_version_mentions = 2.times.map { Fabricate(:mention) }.each do |m|
          existing_version.db[:post_versions_mentions].insert(
            :mention_id => m.id,
            :post_version_id => existing_version.id
          )
        end
        expect(existing_version.attachments_dataset.count).to eql(2)
        expect(existing_version.mentions_dataset.count).to eql(2)

        latest_version = post.create_version!

        post_attrs = {
          :version => existing_version.version
        }

        expect(lambda {
          expect(lambda {
            expect(lambda {
              json_put "/posts/#{post.public_id}", post_attrs, env
              expect(last_response.status).to eq(200)
            }).to change(TentD::Model::PostVersion, :count).by(1)
          }).to_not change(TentD::Model::PostAttachment, :count)
        }).to_not change(TentD::Model::Mention, :count)

        version = post.reload.latest_version

        expect(existing_version.attachments_dataset.count).to eql(2)
        expect(existing_version.mentions_dataset.count).to eql(2)

        expect(version.attachments_dataset.count).to eql(2)
        expect(version.attachments.map(&:id)).to eql(existing_version_attachments.map(&:id))

        expect(version.mentions_dataset.count).to eql(2)
        expect(version.mentions.map(&:id)).to eql(existing_version_mentions.map(&:id))
      end
    end

    context 'when not authorized' do
      it 'should return 403' do
        json_put "/posts/#{post.public_id}", params, env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end
    end
  end
end
