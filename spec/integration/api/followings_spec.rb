require 'spec_helper'

describe TentServer::API::Followings do
  def app
    TentServer::API.new
  end

  describe 'GET /followings' do
    let(:current_auth) { nil }
    let(:create_permissions?) { false }

    before do
      @create_permission = lambda do |following|
        TentServer::Model::Permission.create(
          :following_id => following.id,
          current_auth.permissible_foreign_key => current_auth.id
        )
      end
    end

    with_params = proc do
      context '[:since_id]' do
        it 'should only return followings with id > :since_id' do
          since_following = Fabricate(:following, :public => !create_permissions?)
          following = Fabricate(:following, :public => !create_permissions?)

          if create_permissions?
            [since_following, following].each { |f| @create_permission.call(f) }
          end

          json_get "/followings?since_id=#{since_following.public_uid}", nil, 'current_auth' => current_auth
          expect(last_response.body).to eq([following].to_json)
        end
      end

      context '[:before_id]' do
        it 'should only return followings with id < :before_id' do
          TentServer::Model::Following.all.destroy!
          following = Fabricate(:following, :public => !create_permissions?)
          before_following = Fabricate(:following, :public => !create_permissions?)

          if create_permissions?
            [before_following, following].each { |f| @create_permission.call(f) }
          end

          json_get "/followings?before_id=#{before_following.public_uid}", nil, 'current_auth' => current_auth
          expect(last_response.body).to eq([following].to_json)
        end
      end

      context '[:limit]' do
        it 'should only return :limit number of followings' do
          limit = 1
          followings = 0.upto(limit).map { Fabricate(:following, :public => !create_permissions?) }

          if create_permissions?
            followings.each { |f| @create_permission.call(f) }
          end

          json_get "/followings?limit=#{limit}", nil, 'current_auth' => current_auth
          expect(JSON.parse(last_response.body).size).to eq(limit)
        end

        context 'when [:limit] > TentServer::API::MAX_PER_PAGE' do
          it 'should only return TentServer::API::MAX_PER_PAGE number of followings' do
            with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
              limit = 1
              following = Fabricate(:following, :public => !create_permissions?)

              if create_permissions?
                @create_permission.call(following)
              end

              json_get "/followings?limit=#{limit}", nil, 'current_auth' => current_auth
              expect(JSON.parse(last_response.body).size).to eq(0)
            end
          end
        end
      end

      context 'without [:limit]' do
        it 'should only return TentServer::API::PER_PAGE number of followings' do
          with_constants "TentServer::API::PER_PAGE" => 0 do
            following = Fabricate(:following, :public => !create_permissions?)

            if create_permissions?
              @create_permission.call(following)
            end

            json_get "/followings", nil, 'current_auth' => current_auth
            expect(JSON.parse(last_response.body).size).to eq(0)
          end
        end
      end
    end

    without_permissions = proc do
      it 'should only return public followings' do
        TentServer::Model::Following.all(:public => true).destroy!
        public_following = Fabricate(:following, :public => true)
        private_following = Fabricate(:following, :public => false)

        json_get '/followings', nil, 'current_auth' => current_auth
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body).to include(JSON.parse(public_following.to_json))
        expect(body).to_not include(JSON.parse(private_following.to_json))
      end

      context 'with params', &with_params
    end

    with_permissions = proc do
      context 'when permissible' do
        let(:create_permissions?) { true }
        let(:group) { Fabricate(:group, :name => 'chunky-bacon') }
        let!(:public_following) { Fabricate(:following, :public => true) }
        let!(:private_following) { Fabricate(:following, :public => false) }
        let!(:private_permissible_following) { Fabricate(:following, :public => false) }

        context 'explicitly' do
          it 'should return permissible and public followings' do
            @create_permission.call(private_permissible_following)

            json_get '/followings', nil, 'current_auth' => current_auth
            body = JSON.parse(last_response.body)
            expect(body).to include(JSON.parse(public_following.to_json))
            expect(body).to include(JSON.parse(private_permissible_following.to_json))
            expect(body).to_not include(JSON.parse(private_following.to_json))
          end
        end

        context 'via group' do
          it 'should return permissible and public followings' do
            current_auth.update(:groups => [group.public_uid])
            TentServer::Model::Permission.create(
              :following_id => private_permissible_following.id,
              :group_public_uid => group.public_uid
            )

            json_get '/followings', nil, 'current_auth' => current_auth
            body = JSON.parse(last_response.body)
            expect(body).to include(JSON.parse(public_following.to_json))
            expect(body).to include(JSON.parse(private_permissible_following.to_json))
            expect(body).to_not include(JSON.parse(private_following.to_json))
          end
        end

        context 'with params', &with_params
      end

      context 'when not permissible', &without_permissions
    end

    context 'without current_auth', &without_permissions

    context 'with current_auth' do
      context 'when Follower' do
        let(:current_auth) { Fabricate(:follower) }

        context 'without permissions', &without_permissions

        context 'with permissions', &with_permissions
      end

      context 'when AppAuthorization' do
        let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

        context 'without permissions', &without_permissions

        context 'with permissions', &with_permissions
      end
    end
  end

  describe 'GET /followings/:id' do
    let(:current_auth) { nil }

    without_permissions = proc do
      it 'should return following if public' do
        following = Fabricate(:following, :public => true)
        json_get "/following/#{following.public_uid}", nil, 'current_auth' => current_auth
        expect(last_response.body).to eq(following.to_json)
      end

      it 'should return 404 unless public' do
        following = Fabricate(:following, :public => false)
        json_get "/following/#{following.public_uid}", nil, 'current_auth' => current_auth
        expect(last_response.status).to eq(404)
      end

      it 'should return 404 unless exists' do
        following = Fabricate(:following, :public => true)
        json_get "/following/#{TentServer::Model::Following.count * 100}", nil, 'current_auth' => current_auth
        expect(last_response.status).to eq(404)
      end
    end

    with_permissions = proc do
      context 'explicitly' do
        it 'should return following' do
          following = Fabricate(:following, :public => false)
          TentServer::Model::Permission.create(
            :following_id => following.id,
            current_auth.permissible_foreign_key => current_auth.id
          )
          json_get "/following/#{following.public_uid}", nil, 'current_auth' => current_auth
          expect(last_response.body).to eq(following.to_json)
        end
      end

      context 'via group' do
        it 'should return following' do
          group = Fabricate(:group, :name => 'foo')
          current_auth.update(:groups => [group.public_uid])
          following = Fabricate(:following, :public => false, :groups => [group.public_uid.to_s])
          TentServer::Model::Permission.create(
            :following_id => following.id,
            :group_public_uid => group.public_uid
          )
          json_get "/following/#{following.public_uid}", nil, 'current_auth' => current_auth
          expect(last_response.body).to eq(following.to_json)
        end
      end
    end

    context 'without current_auth', &without_permissions

    context 'with current_auth' do
      context 'when Follower' do
        let(:current_auth) { Fabricate(:follower) }

        context 'when permissible', &with_permissions
        context 'when not permissible', &without_permissions
      end

      context 'when AppAuthorization' do
        let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

        context 'when permissible', &with_permissions
        context 'when not permissible', &without_permissions
      end
    end
  end

  describe 'POST /followings' do
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:tent_entity) { 'https://smith.example.com' } # me
    let(:entity_url) { "https://sam.example.org" } # them
    let(:link_header) {
      %Q(<#{entity_url}/tent/profile>; rel="profile"; type="%s") % TentClient::PROFILE_MEDIA_TYPE
    }
    let(:tent_profile) {
      %Q({"https://tent.io/types/info/core/v0.1.0":{"licenses":["http://creativecommons.org/licenses/by/3.0/"],"entity":"#{entity_url}","servers":["#{entity_url}/tent"]}})
    }
    let(:tent_profile_mismatch) {
     %Q({"https://tent.io/types/info/core/v0.1.0":{"licenses":["http://creativecommons.org/licenses/by/3.0/"],"entity":"https://mismatch.example.org","servers":["#{entity_url}/tent"]}})
    }
    let(:follower) { Fabricate(:follower, :entity => URI(entity_url)) }
    let(:follow_response) { follower.to_json(:only => [:id, :mac_key_id, :mac_key, :mac_algorithm]) }
    let(:group) { Fabricate(:group, :name => 'family') }
    let(:following_data) do
      {
        'entity' => entity_url,
        'groups' => [{ :id => group.public_uid.to_s }]
      }
    end

    before do
      @tent_profile = TentServer::Model::ProfileInfo.create(
        :entity => tent_entity,
        :type => TentServer::Model::ProfileInfo::TENT_PROFILE_TYPE_URI,
        :content => { 
          :licenses => ["http://creativecommons.org/licenses/by/3.0/"]
        }
      )

      @http_stub_head_success = lambda do
        http_stubs.head('/') { [200, { 'Link' => link_header }, ''] }
      end

      @http_stub_profile_success = lambda do
        http_stubs.get('/tent/profile') {
          [200, { 'Content-Type' => TentClient::PROFILE_MEDIA_TYPE }, tent_profile]
        }
      end

      @http_stub_profile_mismatch = lambda do
        http_stubs.get('/tent/profile') {
          [200, { 'Content-Type' => TentClient::PROFILE_MEDIA_TYPE }, tent_profile_mismatch]
        }
      end

      @http_stub_follow_success = lambda do
        http_stubs.post('/followers') { [200, { 'Content-Type' => TentClient::PROFILE_MEDIA_TYPE}, follow_response] }
      end

      @http_stub_success = lambda do
        @http_stub_head_success.call
        @http_stub_profile_success.call
        @http_stub_follow_success.call
      end
    end

    it 'should perform head discovery on following' do
      @http_stub_success.call
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followings', following_data, 'tent.entity' => tent_entity
      http_stubs.verify_stubbed_calls
    end

    it 'should send follow request to following' do
      @http_stub_success.call
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followings', following_data, 'tent.entity' => tent_entity
      http_stubs.verify_stubbed_calls
    end

    context 'when discovery fails' do
      it 'should error 404 when no profile' do
        http_stubs.head('/') { [404, {}, 'Not Found'] }
        http_stubs.get('/') { [404, {}, 'Not Found'] }
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followings', following_data, 'tent.entity' => tent_entity
        expect(last_response.status).to eq(404)
      end

      it 'should error 409 when entity returned does not match' do
        @http_stub_head_success.call
        @http_stub_profile_mismatch.call
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followings', following_data, 'tent.entity' => tent_entity
        expect(last_response.status).to eq(409)
      end
    end

    context 'when follow request fails' do
      it 'should error' do
        @http_stub_head_success.call
        @http_stub_profile_success.call
        http_stubs.post('/followers') { [404, {}, 'Not Found'] }
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followings', following_data, 'tent.entity' => tent_entity
        expect(last_response.status).to eq(404)
      end
    end

    context 'when discovery and follow requests success' do
      before do
        @http_stub_success.call
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      end

      it 'should create following' do
        expect(lambda {
          json_post '/followings', following_data, 'tent.entity' => tent_entity
        }).to change(TentServer::Model::Following, :count).by(1)

        following = TentServer::Model::Following.last
        expect(following.entity.to_s).to eq("https://sam.example.org")
        expect(following.groups).to eq([group.public_uid.to_s])
        expect(following.remote_id).to eq(follower.public_uid.to_s)
        expect(following.mac_key_id).to eq(follower.mac_key_id)
        expect(following.mac_key).to eq(follower.mac_key)
        expect(following.mac_algorithm).to eq(follower.mac_algorithm)

        expect(last_response.body).to eq(following.to_json)
      end
    end
  end

  describe 'DELETE /followings/:id' do
    let!(:following) { Fabricate(:following) }

    context 'when exists' do
      it 'should delete following' do
        expect(lambda { delete "/followings/#{following.public_uid}" }).
          to change(TentServer::Model::Following, :count).by(-1)
      end
    end

    context 'when does not exist' do
      it 'should return 404' do
        expect(lambda { delete "/followings/#{TentServer::Model::Following.count * 100}" }).
          to_not change(TentServer::Model::Following, :count)
        expect(last_response.status).to eq(404)
      end
    end
  end
end
