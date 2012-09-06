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

  let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:follower) { Fabricate(:follower) }
  let(:follower_entity_url) { "https://alex.example.org" }

  describe 'POST /followers' do
    let(:follower_data) do
      {
        "entity" => follower_entity_url,
        "licenses" => ["http://creativecommons.org/licenses/by-nc-sa/3.0/"],
        "types" => ["https://tent.io/types/posts/status/v0.1.x#full", "https://tent.io/types/posts/photo/v0.1.x#meta"]
      }
    end

    it 'should perform discovery' do
      http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
      http_stubs.get('/tent/profile') {
        [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, tent_profile(follower_entity_url)]
      }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com'
      http_stubs.verify_stubbed_calls
    end

    it 'should error if discovery fails' do
      http_stubs.head('/') { [404, {}, 'Not Found'] }
      http_stubs.get('/') { [404, {}, 'Not Found'] }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com'
      expect(last_response.status).to eq(404)
    end

    it 'should fail if entity identifiers do not match' do
      http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
      http_stubs.get('/tent/profile') {
        [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, tent_profile('https://otherentity.example.com')]
      }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com'
      expect(last_response.status).to eq(409)
    end

    context 'when discovery success' do
      before do
        http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
        http_stubs.get('/tent/profile') {
          [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, tent_profile(follower_entity_url)]
        }
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      end

      it 'should create follower db record and respond with hmac secret' do
        expect(lambda { json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com' }).
          to change(TentD::Model::Follower, :count).by(1)
        expect(last_response.status).to eq(200)
        follow = TentD::Model::Follower.last
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(follow.public_id)
        %w{ mac_key_id mac_key mac_algorithm }.each { |key|
          expect(body[key]).to eq(follow.send(key))
        }
      end

      it 'should create notification subscription for each type given' do
        expect(lambda { json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com' }).
          to change(TentD::Model::NotificationSubscription, :count).by(2)
        expect(last_response.status).to eq(200)
        expect(TentD::Model::NotificationSubscription.last.view).to eq('meta')
      end
    end
  end

  describe 'POST /followers with write_followers scope authorized' do
    before {
      authorize!(:write_followers)
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
    }

    let(:follower_data) do
      follower = Fabricate(:follower)
      follower.destroy
      {
        "entity" => follower_entity_url,
        "groups" => follower.groups,
        "profile" => { "info_type_uri" => { "bacon" => "chunky" } },
        "licenses" => follower.licenses,
        "mac_key_id" => follower.mac_key_id,
        "mac_key" => follower.mac_key,
        "mac_algorithm" => follower.mac_algorithm,
        "mac_timestamp_delta" => follower.mac_timestamp_delta,
        "types" => ["https://tent.io/types/posts/status/v0.1.x#full", "https://tent.io/types/posts/photo/v0.1.x#meta"]
      }
    end

    context 'when write_secrets scope authorized' do
      before { authorize!(:write_followers, :write_secrets) }

      it 'should create follower without discovery' do
        expect(lambda { json_post '/followers', follower_data, env }).
          to change(TentD::Model::Follower, :count).by(1)
        expect(last_response.status).to eq(200)
      end

      it 'should create notification subscription for each type given' do
        expect(lambda { json_post '/followers', follower_data, env }).
          to change(TentD::Model::NotificationSubscription, :count).by(2)
        expect(TentD::Model::NotificationSubscription.last.view).to eq('meta')
        expect(last_response.status).to eq(200)
      end
    end

    context 'when write_secrets scope not authorized' do
      it 'should respond 403' do
        expect(lambda { json_post '/followers', follower_data, env }).
          to_not change(TentD::Model::Follower, :count)

        expect(lambda { json_post '/followers', follower_data, env }).
          to_not change(TentD::Model::NotificationSubscription, :count)

        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'GET /followers' do
    authorized_permissible = proc do
      it 'should return a list of followers' do
        TentD::Model::Follower.all.destroy!
        followers = 2.times.map { Fabricate(:follower, :public => true) }
        json_get '/followers', params, env
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        body_ids = body.map { |i| i['id'] }
        followers.each do |follower|
          expect(body_ids).to include(follower.public_id)
        end
      end
    end

    authorized_full = proc do
      it 'should return a list of followers without mac keys' do
        TentD::Model::Follower.all.destroy!
        followers = 2.times.map { Fabricate(:follower, :public => false) }
        json_get '/followers', params, env
        blacklist = %w{ mac_key_id mac_key mac_algorithm }
        body = JSON.parse(last_response.body)
        body.each do |f|
          blacklist.each { |k|
            expect(f).to_not have_key(k)
          }
        end
        expect(last_response.status).to eq(200)
      end
    end

    context 'when not authorized', &authorized_permissible

    context 'when authorized via scope' do
      before { authorize!(:read_followers) }
      context &authorized_full

      context 'when read_secrets authorized' do
        before { authorize!(:read_followers, :read_secrets) }

        context 'when read_secrets param set to true' do
          it 'should return a list of followers with mac keys' do
            TentD::Model::Follower.all.destroy!
            followers = 2.times.map { Fabricate(:follower, :public => false) }
            json_get '/followers?read_secrets=true', params, env
            whitelist = %w{ mac_key_id mac_key mac_algorithm }
            body = JSON.parse(last_response.body)
            body.each do |f|
              whitelist.each { |k|
                expect(f).to have_key(k)
              }
            end
            expect(last_response.status).to eq(200)
          end
        end

        context 'when read_secrets param not set', &authorized_full
      end
    end
  end

  describe 'GET /followers/:id' do
    authorized = proc do
      it 'should respond with follower json' do
        json_get "/followers/#{follower.public_id}", params, env
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['id']).to eq(follower.public_id)
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

        context 'with read_secrets param' do
          before { params['read_secrets'] = true }

          it 'should respond with follower json with mac_key' do
            json_get "/followers/#{follower.public_id}", params, env
            expect(last_response.status).to eq(200)
            actual = JSON.parse(last_response.body)
            expected = follower.as_json(:only => [:id, :groups, :entity, :licenses, :type, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta])
            expected.each_pair do |key, val|
              expect(actual[key.to_s].to_json).to eq(val.to_json)
            end
          end
        end

        context 'without read_secrets param', &authorized
      end

      context 'when no follower exists with :id' do
        it 'should respond with 404' do
          json_get "/followers/invalid-id", params, env
          expect(last_response.status).to eq(404)
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

      context 'with read_secrets param' do
        before { params['read_secrets'] = true }
        context &authorized
      end

      context 'when no follower exists with :id' do
        it 'should respond 403' do
          json_get '/followers/invalid-id', params, env
          expect(last_response.status).to eq(403)
        end
      end
    end

    context 'when not authorized' do
      context 'when follower public' do
        it 'should respond with follower json' do
          json_get "/followers/#{follower.public_id}", params, env
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq(follower.as_json(:only => [:id, :groups, :entity, :licenses, :type]).to_json)
        end
      end

      context 'when follower private' do
        before { follower.update(:public => false) }
        it 'should respond 403' do
          json_get "/followers/#{follower.id}", params, env
          expect(last_response.status).to eq(403)
        end
      end

      context 'when no follower exists with :id' do
        it 'should respond 403' do
          json_get "/followers/invalid-id", params, env
          expect(last_response.status).to eq(403)
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
        expect(follower.licenses).to eq(data[:licenses])
      end

      context '' do
        before(:all) do
          @data = {
            :entity => "https://chunky-bacon.example.com",
            :profile => { :entity => "https:://chunky-bacon.example.com" },
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
            expect(follower.send(property)).to eq(original_value)
          end
        end
        (whitelist || []).each do |property|
          it "should update #{property}" do
            original_value = follower.send(property)
            data = { property => @data[property] }
            json_put "/followers/#{follower.public_id}", data, env
            follower.reload
            actual_value = follower.send(property)
            expect(actual_value.to_json).to eq(@data[property].to_json)
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
          expect(last_response.status).to eq(404)
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
          expect(last_response.status).to eq(403)
        end
      end
    end
  end

  describe 'DELETE /followers/:id' do

    authorized = proc do
      it 'should delete follower' do
        follower # create follower
        expect(lambda { delete "/followers/#{follower.public_id}", params, env }).to change(TentD::Model::Follower, :count).by(-1)
        expect(last_response.status).to eq(200)
      end
    end

    not_authorized = proc do
      it 'should respond 403' do
        delete "/followers/invalid-id", params, env
        expect(last_response.status).to eq(403)
      end
    end

    context 'when authorized via scope' do
      before { authorize!(:write_followers) }

      context &authorized

      it 'should respond with 404 if no follower exists with :id' do
        delete "/followers/invalid-id", params, env
        expect(last_response.status).to eq(404)
      end
    end

    context 'when authorized via identity' do
      before { env['current_auth'] = follower }

      context &authorized

      it 'should respond with 403 if no follower exists with :id' do
        delete "/followers/invalid-id", params, env
        expect(last_response.status).to eq(403)
      end
    end

    context 'when not authorized', &not_authorized
  end
end
