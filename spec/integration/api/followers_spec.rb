require 'spec_helper'

describe TentD::API::Followers do
  def app
    TentD::API.new
  end

  def link_header(entity_url)
    %(<#{entity_url}/tent/profile>; rel="#{TentD::API::PROFILE_REL}")
  end

  def tent_profile(entity_url)
    %({"https://tent.io/types/info/core/v0.1.0":{"licenses":["http://creativecommons.org/licenses/by/3.0/"],"entity":"#{entity_url}","servers":["#{entity_url}/tent"]}})
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
  let(:current_user) { TentD::Model::User.current }
  let(:other_user) { TentD::Model::User.create }

  let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:follower) { Fabricate(:follower) }
  let(:follower_entity_url) { "https://alex.example.org" }

  let(:notification_subscription) do
    Fabricate(:notification_subscription, 
              :type => 'all',
              :app_authorization => Fabricate(:app_authorization,
                                              :scopes => [:read_posts],
                                              :post_types => ['all'],
                                              :app => Fabricate(:app)))
  end

  def stub_challenge!
    http_stubs.get('/tent/notifications/asdf') { |env|
      [200, {}, env[:params]['challenge']]
    }
  end

  describe 'POST /followers' do
    before { env['tent.entity'] = 'https://smith.example.com' }
    let(:follower_data) do
      {
        "entity" => follower_entity_url,
        "licenses" => ["http://creativecommons.org/licenses/by-nc-sa/3.0/"],
        "types" => ["https://tent.io/type/posts/status/v0.1.x#full", "https://tent.io/types/post/photo/v0.1.x#meta"],
        "notification_path" => "notifications/asdf"
      }
    end

    it 'should perform discovery' do
      http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
      http_stubs.get('/tent/profile') {
        [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, tent_profile(follower_entity_url)]
      }
      stub_challenge!
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, env
      http_stubs.verify_stubbed_calls
    end

    context 'when discovery fails' do
      it 'should error 404 when no entities found' do
        http_stubs.head('/') { [404, {}, 'Not Found'] }
        http_stubs.get('/') { [404, {}, 'Not Found'] }
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followers', follower_data, env
        expect(last_response.status).to eql(404)
      end

      it 'should error 503 when connection fails' do
        http_stubs.head('/') { raise Faraday::Error::ConnectionFailed, '' }
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followers', follower_data, env
        expect(last_response.status).to eql(503)
      end

      it 'should error 504 when connection times out' do
        http_stubs.head('/') { raise Faraday::Error::TimeoutError, '' }
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followers', follower_data, env
        expect(last_response.status).to eql(504)
      end
    end


    it 'should error 400 when no post data included' do
      json_post '/followers', nil, env
      expect(last_response.status).to eql(400)
    end

    it 'should fail if challange does not match' do
      http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
      http_stubs.get('/tent/profile') {
        [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, tent_profile('https://otherentity.example.com')]
      }
      challenge = '1234'
      SecureRandom.stubs(:hex).returns(challenge)
      http_stubs.get("/tent/notifications/asdf?challenge=#{challenge}") { [409, {}, ''] }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, env
      expect(last_response.status).to eql(403)
    end

    it 'should fail if entity is self' do
      user = TentD::Model::User.current
      info = TentD::Model::ProfileInfo.first_or_create(:type_base => TentD::Model::ProfileInfo::TENT_PROFILE_TYPE.base, :type_version => TentD::Model::ProfileInfo::TENT_PROFILE_TYPE.version.to_s, :user_id => user.id)
      info.update(:content => { :entity => follower_entity_url })
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      expect(lambda {
        json_post '/followers', follower_data, env
        expect(last_response.status).to eql(406)
      }).to_not change(TentD::Model::Follower, :count)
    end

    context 'when discovery success' do
      before do
        http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
        http_stubs.get('/tent/profile') {
          [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, tent_profile(follower_entity_url)]
        }
        stub_challenge!
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      end

      it 'should create follower db record and respond with hmac secret' do
        expect(lambda { json_post '/followers', follower_data, env }).
          to change(TentD::Model::Follower.where(:user_id => current_user.id), :count).by(1)
        expect(last_response.status).to eql(200)
        follow = TentD::Model::Follower.order(:id.asc).last
        body = JSON.parse(last_response.body)
        expect(body['id']).to eql(follow.public_id)
        %w{ mac_key_id mac_key mac_algorithm }.each { |key|
          expect(body[key]).to eql(follow.send(key))
        }
      end

      context 'when follower already exists' do
        let!(:follower) { Fabricate(:follower, :entity => follower_entity_url) }

        it 'should use existing db record and respond with new hmac secret' do
          expect(lambda {
            json_post '/followers', follower_data, env
          }).to_not change(TentD::Model::Follower, :count)
          expect(last_response.status).to eq(200)

          mac_key_id = follower.mac_key_id
          old_mac_key = follower.mac_key

          follow = follower.class.first(:id => follower.id)
          expect(follow).to_not be_nil

          body = Yajl::Parser.parse(last_response.body)
          expect(body['id']).to eql(follow.public_id)
          %w{ mac_key_id mac_key mac_algorithm }.each { |key|
            expect(body[key]).to eql(follow.send(key))
          }
          expect(follow.mac_key_id).to eql(mac_key_id)
          expect(follow.mac_key).to_not eql(old_mac_key)
        end
      end

      it 'should create post (notification)' do
        expect(lambda {
          json_post '/followers', follower_data, env
          expect(last_response.status).to eql(200)
        }).to change(TentD::Model::Post.where(:user_id => current_user.id), :count).by(1)

        post = TentD::Model::Post.order(:id.asc).last
        expect(post.type.base).to eql('https://tent.io/types/post/follower')
        expect(post.type.version).to eql('0.1.0')
        expect(post.content['action']).to eql('create')
      end

      context 'when follower visibililty is public' do
        it 'should send notification to subscribed followings' do
          follower_data['public'] = true
          expect(lambda {
            json_post '/followers', follower_data, env
            expect(last_response.status).to eql(200)
          }).to change(TentD::Model::Post.where(:user_id => current_user.id), :count).by(1)
          post = TentD::Model::Post.order(:id.asc).last
          expect(post.public).to be_true
          expect(post.original).to be_true
        end
      end

      it 'should create notification subscription for each type given' do
        expect(lambda { json_post '/followers', follower_data, env }).
          to change(TentD::Model::NotificationSubscription.where(:user_id => current_user.id), :count).by(2)
        expect(last_response.status).to eql(200)
        expect(TentD::Model::NotificationSubscription.order(:id.asc).last.type_view).to eql('meta')
      end
    end
  end

  describe 'POST /followers with write_followers scope authorized' do
    before {
      authorize!(:write_followers)
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
    }

    let!(:follower_data) do
      follower = Fabricate(:follower)
      data = {
        "id" => SecureRandom.hex(4),
        "entity" => follower_entity_url,
        "groups" => follower.groups,
        "profile" => { "info_type_uri" => { "bacon" => "chunky" } },
        "notification_path" => follower.notification_path,
        "licenses" => follower.licenses,
        "mac_key_id" => follower.mac_key_id,
        "mac_key" => follower.mac_key,
        "mac_algorithm" => follower.mac_algorithm,
        "mac_timestamp_delta" => follower.mac_timestamp_delta,
        "types" => ["https://tent.io/types/post/status/v0.1.x#full", "https://tent.io/types/post/photo/v0.1.x#meta"]
      }
      TentD::Model::Follower.delete
      data
    end

    context 'when write_secrets scope authorized' do
      before { authorize!(:write_followers, :write_secrets) }

      it 'should create follower without discovery' do
        data = follower_data
        expect(lambda {
          json_post '/followers', data, env
          expect(last_response.status).to eql(200)
        }).to change(TentD::Model::Follower.where(:user_id => current_user.id), :count).by(1)

        follower = TentD::Model::Follower.order(:id.asc).last
        expect(follower.public_id).to eql(data['id'])
        %w( entity groups profile notification_path licenses mac_key_id mac_key mac_algorithm mac_timestamp_delta ).each { |k|
          expect(follower.send(k)).to eql(data[k])
        }
      end

      it 'should create notification subscription for each type given' do
        expect(lambda {
          json_post '/followers', follower_data, env
          expect(last_response.status).to eql(200)
        }).to change(TentD::Model::NotificationSubscription.where(:user_id => current_user.id), :count).by(2)
        expect(TentD::Model::NotificationSubscription.order(:id.asc).last.type_view).to eql('meta')
      end
    end

    context 'when write_secrets scope not authorized' do
      it 'should respond 403' do
        expect(lambda { json_post '/followers', follower_data, env }).
          to_not change(TentD::Model::Follower.where(:user_id => current_user.id), :count)

        expect(lambda { json_post '/followers', follower_data, env }).
          to_not change(TentD::Model::NotificationSubscription.where(:user_id => current_user.id), :count)

        expect(last_response.status).to eql(403)
      end
    end
  end

  describe 'HEAD /followers' do
    it 'should return count of followers' do
      follower = Fabricate(:follower, :public => true)
      other_follower = Fabricate(:follower, :public => true, :user_id => other_user.id)
      head '/followers', params, env
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Count']).to eql('1')

      TentD::Model::Follower.delete
      head '/followers', params, env
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Count']).to eql('0')
    end
  end

  describe 'GET /followers/count' do
    it 'should return count of followers' do
      follower = Fabricate(:follower, :public => true)
      other_follower = Fabricate(:follower, :public => true, :user_id => other_user.id)
      json_get '/followers/count', params, env
      expect(last_response.body).to eql(1.to_json)

      TentD::Model::Follower.delete
      json_get '/followers/count', params, env
      expect(last_response.body).to eql(0.to_json)
    end
  end

  describe 'GET /followers' do
    authorized_permissible = proc do
      it 'should order id desc' do
        first_follower = Fabricate(:follower, :public => true)
        last_follower = Fabricate(:follower, :public => true)

        json_get "/followers", params, env
        body = JSON.parse(last_response.body)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids).to eql([last_follower.public_id, first_follower.public_id])
      end

      it 'should return a list of followers' do
        followers = 2.times.map { Fabricate(:follower, :public => true) }
        json_get '/followers', params, env
        expect(last_response.status).to eql(200)
        body = JSON.parse(last_response.body)
        body_ids = body.map { |i| i['id'] }
        followers.each do |follower|
          expect(body_ids).to include(follower.public_id)
        end
      end

      it 'should only return followers for current user' do
        follower = Fabricate(:follower, :public => true)
        other_follower = Fabricate(:follower, :public => true, :user_id => other_user.id)

        json_get "/followers", params, env
        body = JSON.parse(last_response.body)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.size).to eq(1)
        expect(body_ids).to eql([follower.public_id])
      end
    end

    authorized_full = proc do
      it 'should return a list of followers without mac keys' do
        followers = 2.times.map { Fabricate(:follower, :public => false) }
        json_get '/followers', params, env
        blacklist = %w{ mac_key_id mac_key mac_algorithm }
        body = JSON.parse(last_response.body)
        body.each do |f|
          blacklist.each { |k|
            expect(f).to_not have_key(k)
          }
        end
        expect(last_response.status).to eql(200)
      end

      it 'should only return followers for current user' do
        follower = Fabricate(:follower, :public => false)
        other_follower = Fabricate(:follower, :public => false, :user_id => other_user.id)

        json_get "/followers", params, env
        body = JSON.parse(last_response.body)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids.size).to eq(1)
        expect(body_ids).to eql([follower.public_id])
      end
    end

    context 'when not authorized', &authorized_permissible

    context 'when authorized via scope' do
      before { authorize!(:read_followers) }
      context &authorized_full

      context 'when read_secrets authorized' do
        before { authorize!(:read_followers, :read_secrets) }

        context 'when secrets param set to true' do
          it 'should return a list of followers with mac keys' do
            followers = 2.times.map { Fabricate(:follower, :public => false) }
            json_get '/followers?secrets=true', params, env
            whitelist = %w{ mac_key_id mac_key mac_algorithm }
            body = JSON.parse(last_response.body)
            body.each do |f|
              whitelist.each { |k|
                expect(f).to have_key(k)
              }
            end
            expect(last_response.status).to eql(200)
          end
        end

        context 'when secrets param not set', &authorized_full
      end
    end
  end

  describe 'GET /followers/:entity' do
    authorized = proc {
      it 'should redirect to /followers/:id' do
        json_get "/followers/#{URI.encode_www_form_component(follower.entity)}", params, env
        expect(last_response.status).to eql(302)
        expect(last_response.headers['Location']).to eql("http://example.org/followers/#{follower.id}")
      end
    }

    not_found = proc {
      it 'should return 404' do
        json_get "/followers/#{URI.encode_www_form_component(follower.entity)}", params, env
        expect(last_response.status).to eql(404)
      end
    }

    not_authorized = proc {
      it 'should return 403' do
        json_get "/followers/#{URI.encode_www_form_component(follower.entity)}", params, env
        expect(last_response.status).to eql(403)
      end
    }

    context 'when authorized via scope' do
      before { authorize!(:read_followers) }
      context &authorized

      context 'when follower private' do
        before { follower.update(:public => false) }
        context &authorized
      end

      context 'when follower belongs to another user' do
        before { follower.update(:user_id => other_user.id) }

        context &not_found
      end

      context 'when no follower exists with :entity' do
        let(:follower) { Hashie::Mash.new(:entity => 'http://example.com/foo') }

        context &not_found
      end
    end

    context 'when authorized via identity' do
      before { env['current_auth'] = follower }
      context &authorized

      context 'when follower private' do
        before { follower.update(:public => false) }
        context &authorized
      end

      context 'with secrets param' do
        before { params['secrets'] = true }
        context &authorized
      end

      context 'when no follower exists with :entity' do
        let(:follower) { Hashie::Mash.new(:entity => 'non-existing') }

        context &not_authorized
      end
    end

    context 'when not authorized' do
      context 'when follower public' do
        context &authorized

        context 'when follower belongs to another user' do
          let(:follower) { Fabricate(:follower, :user_id => other_user.id, :public => true) }

          context &not_authorized
        end
      end

      context 'when follower private' do
        before { follower.update(:public => false) }

        context &not_authorized
      end

      context 'when no follower exists with :entity' do
        let(:follower) { Hashie::Mash.new(:entity => 'non-existing') }

        context &not_authorized
      end
    end
  end

  describe 'GET /followers/:id' do
    authorized = proc do
      it 'should respond with follower json' do
        json_get "/followers/#{follower.public_id}", params, env
        expect(last_response.status).to eql(200)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eql(follower.public_id)
      end

      context 'when follower belongs to another user' do
        let(:follower) { Fabricate(:follower, :user_id => other_user.id) }

        it 'should return 404' do
          json_get "/followers/#{follower.public_id}", params, env
          expect([404, 403]).to include(last_response.status)
        end
      end
    end

    context 'when authorized via scope' do
      before { authorize!(:read_followers) }
      context &authorized

      context 'when follower private' do
        before { follower.update(:public => false) }
        context &authorized
      end

      context 'when read_secrets scope authorized' do
        before { authorize!(:read_followers, :read_secrets) }

        context 'with secrets param' do
          before { params['secrets'] = true }

          it 'should respond with follower json with mac_key' do
            json_get "/followers/#{follower.public_id}", params, env
            expect(last_response.status).to eql(200)
            actual = JSON.parse(last_response.body)
            expected = follower.as_json(:only => [:id, :groups, :entity, :licenses, :type, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta])
            expected.each_pair do |key, val|
              expect(actual[key.to_s].to_json).to eql(val.to_json)
            end
          end
        end

        context 'without secrets param', &authorized
      end

      context 'when no follower exists with :id' do
        it 'should respond with 404' do
          json_get "/followers/invalid-id", params, env
          expect(last_response.status).to eql(404)
        end
      end
    end

    context 'when authorized via identity' do
      before { env['current_auth'] = follower }
      context &authorized

      context 'when follower private' do
        before { follower.update(:public => false) }
        context &authorized
      end

      context 'with secrets param' do
        before { params['secrets'] = true }
        context &authorized
      end

      context 'when no follower exists with :id' do
        it 'should respond 403' do
          json_get '/followers/invalid-id', params, env
          expect(last_response.status).to eql(403)
        end
      end
    end

    context 'when not authorized' do
      context 'when follower public' do
        it 'should respond with follower json' do
          json_get "/followers/#{follower.public_id}", params, env
          expect(last_response.status).to eql(200)
          expect(last_response.body).to eql(follower.as_json(:only => [:id, :groups, :entity, :licenses, :type]).to_json)
        end

        context 'when follower belongs to another user' do
          let(:follower) { Fabricate(:follower, :user_id => other_user.id, :public => true) }

          it 'should return 403' do
            json_get "/followers/#{follower.public_id}", params, env
            expect(last_response.status).to eq(403)
          end
        end
      end

      context 'when follower private' do
        before { follower.update(:public => false) }
        it 'should respond 403' do
          json_get "/followers/#{follower.id}", params, env
          expect(last_response.status).to eql(403)
        end
      end

      context 'when no follower exists with :id' do
        it 'should respond 403' do
          json_get "/followers/invalid-id", params, env
          expect(last_response.status).to eql(403)
        end
      end
    end
  end

  describe 'PUT /followers/:id' do
    blacklist = whitelist = []
    authorized = proc do |*args|
      it 'should update follower licenses' do
        data = {
          :licenses => ["http://creativecommons.org/licenses/by/3.0/"]
        }
        json_put "/followers/#{follower.public_id}", data, env
        follower.reload
        expect(follower.licenses).to eql(data[:licenses])
      end

      context 'when follower belongs to another user' do
        it 'should return 404' do
          data = {
            :licenses => ["http://creativecommons.org/licenses/by/3.0/"]
          }
          follower.update(:user_id => other_user.id)
          json_put "/followers/#{follower.public_id}", data, env
          expect([404, 403]).to include(last_response.status)
        end
      end

      context '' do
        before(:all) do
          @data = {
            :entity => "https://chunky-bacon.example.com",
            :profile => { 'entity' => "https:://chunky-bacon.example.com" },
            :type => :following,
            :public => true,
            :groups => ['group-id', 'group-id-2'],
            :mac_key_id => '12345',
            :mac_key => '12312',
            :mac_algorithm => 'sdfjhsd',
            :mac_timestamp_delta => 124123
          }
        end
        (blacklist || []).each do |property|
          it "should not update #{property}" do
            original_value = follower.send(property)
            data = { property => @data[property] }
            json_put "/followers/#{follower.public_id}", data, env
            follower.reload
            expect(follower.send(property)).to eql(original_value)
          end
        end
        (whitelist || []).each do |property|
          it "should update #{property}" do
            original_value = follower.send(property)
            data = { property => @data[property] }
            json_put "/followers/#{follower.public_id}", data, env
            follower.reload
            actual_value = follower.send(property)
            expect(actual_value.to_json).to eql(@data[property].to_json)
          end
        end
      end

      it 'should update follower type notifications' do
        data = {
          :types => follower.notification_subscriptions.map {|ns| ns.type.to_s}.concat(["https://tent.io/types/post/video/v0.1.x#meta"])
        }
        expect( lambda { json_put "/followers/#{follower.public_id}", data, env } ).
          to change(TentD::Model::NotificationSubscription, :count).by (1)

        follower.reload
        data = {
          :types => follower.notification_subscriptions.map {|ns| ns.type.to_s}[0..-2]
        }
        expect( lambda { json_put "/followers/#{follower.public_id}", data, env } ).
          to change(TentD::Model::NotificationSubscription, :count).by (-1)
      end
    end

    context 'when authorized via scope' do
      before { authorize!(:write_followers) }
      blacklist = [:mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta]
      whitelist = [:entity, :profile, :public, :groups]
      context &authorized

      context 'when no follower exists with :id' do
        it 'should respond 404' do
          json_put '/followers/invalid-id', params, env
          expect(last_response.status).to eql(404)
        end
      end

      context 'when write_secrets scope authorized' do
        before { authorize!(:write_followers, :write_secrets) }
        blacklist = []
        whitelist = [:entity, :profile, :public, :groups, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta]
        context &authorized
      end
    end

    context 'when authorized via identity' do
      before { env['current_auth'] = follower }
      blacklist = [:entity, :profile, :public, :groups, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta]
      whitelist = []
      context &authorized

      context 'when no follower exists with :id' do
        it 'should respond 403' do
          json_put '/followers/invalid-id', params, env
          expect(last_response.status).to eql(403)
        end
      end
    end
  end

  describe 'DELETE /followers/:id' do

    authorized = proc do
      it 'should delete follower' do
        follower # create follower
        expect(lambda {
          delete "/followers/#{follower.public_id}", params, env
          expect(last_response.status).to eql(200)
        }).to change(TentD::Model::Follower.where(:user_id => current_user.id), :count).by(-1)

        deleted_follower = TentD::Model::Follower.unfiltered.first(:id => follower.id)
        expect(deleted_follower).to_not be_nil
        expect(deleted_follower.deleted_at).to_not be_nil
      end

      it 'should create post (notification)' do
        follower # create follower

        expect(lambda {
          delete "/followers/#{follower.public_id}", params, env
          expect(last_response.status).to eql(200)
        }).to change(TentD::Model::Post.where(:user_id => current_user.id), :count).by(1)

        post = TentD::Model::Post.order(:id.asc).last
        expect(post.type.base).to eql('https://tent.io/types/post/follower')
        expect(post.type.version).to eql('0.1.0')
        expect(post.content['action']).to eql('delete')
      end

      context 'when follower belongs to another user' do
        it 'should return 404' do
          follower.update(:user_id => other_user.id)
          expect(lambda {
            delete "/followers/#{follower.public_id}", params, env
            expect([404, 403]).to include(last_response.status)
          }).to_not change(TentD::Model::Follower, :count)
        end
      end
    end

    not_authorized = proc do
      it 'should respond 403' do
        delete "/followers/invalid-id", params, env
        expect(last_response.status).to eql(403)
      end
    end

    context 'when authorized via scope' do
      before { authorize!(:write_followers) }

      context &authorized

      it 'should respond with 404 if no follower exists with :id' do
        delete "/followers/invalid-id", params, env
        expect(last_response.status).to eql(404)
      end
    end

    context 'when authorized via identity' do
      before { env['current_auth'] = follower }

      context &authorized

      it 'should respond with 403 if no follower exists with :id' do
        delete "/followers/invalid-id", params, env
        expect(last_response.status).to eql(403)
      end
    end

    context 'when not authorized', &not_authorized
  end
end
