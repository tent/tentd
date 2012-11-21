require 'spec_helper'

describe TentD::API::Followings do
  def app
    TentD::API.new
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

  def stub_notification_http!
    http_stubs.post('/notifications') { [200, {}, []] }
  end

  describe 'GET /followings/count' do
    it 'should return count of followings' do
      following = Fabricate(:following, :public => true)
      json_get '/followings/count', params, env
      expect(last_response.body).to eql(1.to_json)
    end
  end

  describe 'GET /followings' do
    let(:create_permissions?) { false }
    let(:current_auth) { env['current_auth'] }

    before do
      @create_permission = lambda do |following|
        TentD::Model::Permission.create(
          :following_id => following.id,
          current_auth.permissible_foreign_key => current_auth.id
        )
      end
    end

    with_params = proc do
      it 'should order id desc' do
        TentD::Model::Following.destroy
        first_following = Fabricate(:following, :public => true)
        last_following = Fabricate(:following, :public => true)

        json_get "/followings", params, env
        body = JSON.parse(last_response.body)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids).to eql([last_following.public_id, first_following.public_id])
      end

      context '[:entity]' do
        it 'should only return followings with matching entity uri' do
          other = Fabricate(:following)
          following = Fabricate(:following, :public => true, :entity => 'https://123smith.example.org')

          json_get "/followings?entity=#{URI.encode_www_form_component(following.entity)}"
          expect(last_response.status).to eql(200)
          body = JSON.parse(last_response.body)
          expect(body.size).to eql(1)
          expect(body.first['id']).to eql(following.public_id)
        end
      end

      context '[:since_id]' do
        it 'should only return followings with id > :since_id' do
          since_following = Fabricate(:following, :public => !create_permissions?)
          following = Fabricate(:following, :public => !create_permissions?)

          if create_permissions?
            [since_following, following].each { |f| @create_permission.call(f) }
          end

          json_get "/followings?since_id=#{since_following.public_id}", params, env
          expect(last_response.status).to eql(200)
          body = JSON.parse(last_response.body)
          expect(body.size).to eql(1)
          expect(body.first['id']).to eql(following.public_id)
        end
      end

      context '[:before_id]' do
        it 'should only return followings with id < :before_id' do
          TentD::Model::Following.destroy
          following = Fabricate(:following, :public => !create_permissions?)
          before_following = Fabricate(:following, :public => !create_permissions?)

          if create_permissions?
            [before_following, following].each { |f| @create_permission.call(f) }
          end

          json_get "/followings?before_id=#{before_following.public_id}", params, env
          expect(last_response.status).to eql(200)
          body = JSON.parse(last_response.body)
          expect(body.size).to eql(1)
          expect(body.first['id']).to eql(following.public_id)
        end
      end

      context '[:limit]' do
        it 'should only return :limit number of followings' do
          limit = 1
          followings = 0.upto(limit).map { Fabricate(:following, :public => !create_permissions?) }

          if create_permissions?
            followings.each { |f| @create_permission.call(f) }
          end

          json_get "/followings?limit=#{limit}", params, env
          expect(JSON.parse(last_response.body).size).to eql(limit)
        end

        context 'when [:limit] > TentD::API::MAX_PER_PAGE' do
          it 'should only return TentD::API::MAX_PER_PAGE number of followings' do
            with_constants "TentD::API::MAX_PER_PAGE" => 0 do
              limit = 1
              following = Fabricate(:following, :public => !create_permissions?)

              if create_permissions?
                @create_permission.call(following)
              end

              json_get "/followings?limit=#{limit}", params, env
              expect(JSON.parse(last_response.body).size).to eql(0)
            end
          end
        end
      end

      context 'without [:limit]' do
        it 'should only return TentD::API::PER_PAGE number of followings' do
          with_constants "TentD::API::PER_PAGE" => 0 do
            following = Fabricate(:following, :public => !create_permissions?)

            if create_permissions?
              @create_permission.call(following)
            end

            json_get "/followings", params, env
            expect(JSON.parse(last_response.body).size).to eql(0)
          end
        end
      end
    end

    without_permissions = proc do
      it 'should only return public followings' do
        public_following = Fabricate(:following, :public => true)
        private_following = Fabricate(:following, :public => false)

        json_get '/followings', params, env
        expect(last_response.status).to eql(200)
        body = JSON.parse(last_response.body)
        body_ids = body.map { |f| f['id'] }
        expect(body_ids).to include(public_following.public_id)
        expect(body_ids).to_not include(private_following.public_id)
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

        permissible_and_public = proc do
          it 'should return permissible and public followings' do
            json_get '/followings', params, env
            body = JSON.parse(last_response.body)
            body_ids = body.map { |f| f['id'] }
            expect(body_ids).to include(public_following.public_id)
            expect(body_ids).to include(private_permissible_following.public_id)
            expect(body_ids).to_not include(private_following.public_id)
          end
        end

        context 'explicitly' do
          before {
            @create_permission.call(private_permissible_following)
          }

          context &permissible_and_public
        end

        context 'via group' do
          before {
            current_auth.update(:groups => [group.public_id])
            TentD::Model::Permission.create(
              :following_id => private_permissible_following.id,
              :group_public_id => group.public_id
            )
          }

          context &permissible_and_public
        end

        context 'with params', &with_params
      end

      context 'when not permissible', &without_permissions
    end

    context 'without read_followings scope authorized' do
      context 'without current_auth', &without_permissions

      context 'with current_auth' do
        context 'when Follower' do
          before{ env['current_auth'] = Fabricate(:follower) }

          context 'without permissions', &without_permissions

          context 'with permissions', &with_permissions
        end

        context 'when AppAuthorization' do
          before { env['current_auth'] = Fabricate(:app_authorization, :app => Fabricate(:app)) }

          context &without_permissions
        end
      end
    end

    context 'with read_followings scope authorized' do
      before { authorize!(:read_followings) }

      it 'should return all followings without mac keys' do
        Fabricate(:following, :public => true)
        Fabricate(:following, :public => false)
        count = TentD::Model::Following.count
        with_constants "TentD::API::MAX_PER_PAGE" => count do
          json_get '/followings', params, env
          expect(last_response.status).to eql(200)
          body = JSON.parse(last_response.body)
          expect(body.size).to eql(count)
          blacklist = %w{ mac_key_id mac_key mac_algorithm mac_timestamp_delta }
          body.each do |actual|
            blacklist.each { |k|
              expect(actual).to_not have_key(k)
            }
          end
        end
      end

      context 'and read_secrets scope authorized' do
        before {
          authorize!(:read_followings, :read_secrets)
          params['secrets'] = true
        }

        it 'should return all followings with mac keys' do
          Fabricate(:following, :public => false)
          json_get '/followings', params, env
          expect(last_response.status).to eql(200)
          body = JSON.parse(last_response.body)
          whitelist = %w{ mac_key_id mac_key mac_algorithm }
          body.each do |actual|
            whitelist.each { |k|
              expect(actual).to have_key(k)
            }
          end
        end
      end

      context 'with params', &with_params
    end
  end

  describe 'GET /followings/:id' do
    let(:current_auth) { env['current_auth'] }

    without_permissions = proc do
      it 'should return following if public' do
        following = Fabricate(:following, :public => true)
        json_get "/followings/#{following.public_id}", params, env
        expect(JSON.parse(last_response.body)['id']).to eql(following.public_id)
      end

      it 'should return 403 unless public' do
        following = Fabricate(:following, :public => false)
        json_get "/followings/#{following.public_id}", params, env
        expect(last_response.status).to eql(403)
      end

      it 'should return 403 unless exists' do
        following = Fabricate(:following, :public => true)
        json_get "/followings/invalid-id", params, env
        expect(last_response.status).to eql(403)
      end
    end

    with_permissions = proc do
      context 'explicitly' do
        it 'should return following' do
          following = Fabricate(:following, :public => false)
          TentD::Model::Permission.create(
            :following_id => following.id,
            current_auth.permissible_foreign_key => current_auth.id
          )
          json_get "/followings/#{following.public_id}", params, env
          expect(JSON.parse(last_response.body)['id']).to eql(following.public_id)
        end
      end

      context 'via group' do
        it 'should return following' do
          group = Fabricate(:group, :name => 'foo')
          current_auth.update(:groups => [group.public_id])
          following = Fabricate(:following, :public => false, :groups => [group.public_id.to_s])
          TentD::Model::Permission.create(
            :following_id => following.id,
            :group_public_id => group.public_id
          )
          json_get "/followings/#{following.public_id}", params, env
          expect(JSON.parse(last_response.body)['id']).to eql(following.public_id)
        end
      end
    end

    context 'when read_followings scope not authorized' do
      context 'without current_auth', &without_permissions

      context 'with current_auth' do
        context 'when Follower' do
          before { env['current_auth'] = Fabricate(:follower) }

          context 'when permissible', &with_permissions
          context 'when not permissible', &without_permissions
        end

        context 'when AppAuthorization' do
          before { env['current_auth'] = Fabricate(:app_authorization, :app => Fabricate(:app)) }

          context &without_permissions
        end
      end
    end

    context 'when read_followings scope authorized' do
      before { authorize!(:read_followings) }

      it 'should return private following without mac keys' do
        following = Fabricate(:following, :public => false)
        json_get "/followings/#{following.public_id}", params, env
        expect(last_response.status).to eql(200)
        body = JSON.parse(last_response.body)
        blacklist = %w{ mac_key_id mac_key mac_algorithm mac_timestamp_delta }
        blacklist.each { |k|
          expect(body).to_not have_key(k)
        }
        expect(body['id']).to eql(following.public_id)
      end

      it 'should return public following without mac keys' do
        following = Fabricate(:following, :public => true)
        json_get "/followings/#{following.public_id}", params, env
        expect(last_response.status).to eql(200)
        body = JSON.parse(last_response.body)
        blacklist = %w{ mac_key_id mac_key mac_algorithm mac_timestamp_delta }
        blacklist.each { |k|
          expect(body).to_not have_key(k)
        }
        expect(body['id']).to eql(following.public_id)
      end

      context 'when read_secrets scope authorized' do
        before {
          authorize!(:read_followings, :read_secrets)
          params['secrets'] = true
        }

        it 'should return following with mac keys' do
          following = Fabricate(:following, :public => true)
          json_get "/followings/#{following.public_id}", params, env
          expect(last_response.status).to eql(200)
          body = JSON.parse(last_response.body)
          whitelist = %w{ mac_key_id mac_key mac_algorithm }
          expect(body['id']).to eql(following.public_id)
          whitelist.each { |k|
            expect(body).to have_key(k)
          }
        end
      end

      it 'should return 404 if no following with :id exists' do
        json_get '/followings/invalid-id', params, env
        expect(last_response.status).to eql(404)
      end
    end
  end

  describe 'POST /followings' do
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:tent_entity) { 'https://smith.example.com' } # me
    let(:entity_url) { "https://sam.example.org" } # them
    let(:actual_entity_url) { "https://sam-actual.example.com" } # them
    let(:link_header) {
      %(<#{entity_url}/tent/profile>; rel="#{TentD::API::PROFILE_REL}")
    }
    let(:tent_profile) {
      %({"https://tent.io/types/info/core/v0.1.0":{"licenses":["http://creativecommons.org/licenses/by/3.0/"],"entity":"#{actual_entity_url}","servers":["#{actual_entity_url}/tent"]}})
    }
    let(:follower) { Fabricate(:follower, :entity => entity_url) }
    let(:follow_response) { { :id => follower.public_id }.merge(follower.attributes.slice(:mac_key_id, :mac_key, :mac_algorithm)) }
    let(:group) { Fabricate(:group, :name => 'family') }
    let(:following_data) do
      {
        'entity' => entity_url,
        'groups' => [{ :id => group.public_id.to_s }]
      }
    end

    context 'when write_followings scope authorized' do
      before do
        @tent_profile = TentD::Model::ProfileInfo.create(
          :type => TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI,
          :content => {
            :licenses => ["http://creativecommons.org/licenses/by/3.0/"]
          }
        )

        @http_stub_head_success = lambda do
            expect(true)
          http_stubs.head('/') { [200, { 'Link' => link_header }, ''] }
        end

        @http_stub_profile_success = lambda do
          expect(true)
          http_stubs.get('/tent/profile') {
            [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, tent_profile]
          }
        end

        @http_stub_follow_success = lambda do
          http_stubs.post('/tent/followers') {
            expect(true)
            [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, follow_response]
          }
        end

        @http_stub_success = lambda do
          @http_stub_head_success.call
          @http_stub_profile_success.call
          @http_stub_follow_success.call
          stub_notification_http!
        end

        authorize!(:write_followings)
        env['tent.entity'] = tent_entity
      end

      it 'should perform head discovery on following' do
        @http_stub_success.call
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followings', following_data, env
      end

      it 'should send follow request to following' do
        @http_stub_success.call
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

        json_post '/followings', following_data, env
      end

      context 'when write_secrets authorized' do
        before { authorize!(:write_followings, :write_secrets) }

        context 'when auth details present' do
          it 'should create following without sending follow request' do
            @http_stub_head_success.call
            @http_stub_profile_success.call
            stub_notification_http!
            TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

            data = following_data.merge(
              :id => 'public-id',
              :mac_key_id => 'mac-key-id',
              :mac_key => 'mac-key',
              :mac_algorithm => 'hmac-sha-256'
            )

            expect(lambda {
              json_post 'followings', data, env
            }).to change(TentD::Model::Following, :count).by(1)

            following = TentD::Model::Following.order(:id.asc).last
            expect(following.public_id).to eql(data[:id])
            expect(following.mac_key_id).to eql(data[:mac_key_id])
            expect(following.mac_key).to eql(data[:mac_key])
            expect(following.mac_algorithm).to eql(data[:mac_algorithm])
            expect(following.confirmed).to eql(true)
          end
        end

        context 'when auth details not present' do
          it 'should send follow request to following' do
            @http_stub_success.call
            TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

            json_post '/followings', following_data, env
          end
        end
      end

      context 'when discovery fails' do
        it 'should error 404 when no profile' do
          http_stubs.head('/') { [404, {}, 'Not Found'] }
          http_stubs.get('/') { [404, {}, 'Not Found'] }
          TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

          json_post '/followings', following_data, env
          expect(last_response.status).to eql(404)
        end
      end

      context 'when follow request fails' do
        it 'should error' do
          @http_stub_head_success.call
          @http_stub_profile_success.call
          http_stubs.post('/tent/followers') { [404, {}, 'Not Found'] }
          TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

          json_post '/followings', following_data, env
          expect(last_response.status).to eql(404)
        end
      end

      context 'when already following entity' do
        before do
          @http_stub_success.call
          TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
        end

        context 'when confirmed following' do
          it 'should return 409' do
            Fabricate(:following, :entity => following_data['entity'], :confirmed => true)
            expect(lambda {
              json_post '/followings', following_data, env
            }).to change(TentD::Model::Following, :count).by(0)
            expect(last_response.status).to eql(409)
          end
        end

        context 'when unconfirmed following' do
          it 'should use existing following and ping the other server again' do
            @http_stub_success.call
            stub_notification_http!

            following = Fabricate(:following, :entity => following_data['entity'], :confirmed => false)
            expect(lambda {
              json_post '/followings', following_data, env
            }).to change(TentD::Model::Following, :count).by(0)
            expect(last_response.status).to eql(200)
            expect(following.reload.confirmed).to eql(true)
          end
        end
      end

      context 'when discovery and follow requests success' do
        before do
          @http_stub_success.call
          stub_notification_http!
          TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
        end

        it 'should create following' do
          expect(lambda {
            json_post '/followings', following_data, env
          }).to change(TentD::Model::Following, :count).by(1)

          following = TentD::Model::Following.order(:id.asc).last
          expect(following.entity.to_s).to eql(actual_entity_url)
          expect(following.groups).to eql([group.public_id.to_s])
          expect(following.remote_id).to eql(follower.public_id.to_s)
          expect(following.mac_key_id).to eql(follower.mac_key_id)
          expect(following.mac_key).to eql(follower.mac_key)
          expect(following.mac_algorithm).to eql(follower.mac_algorithm)

          expect(JSON.parse(last_response.body)['id']).to eql(following.public_id)
        end
      end
    end

    context 'when write_followings scope unauthorized' do
      before {
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      }

      it 'should return 403' do
        json_post '/followings', params, env
        expect(last_response.status).to eql(403)
      end
    end
  end

  describe 'PUT /followings/:id' do
    let!(:following) { Fabricate(:following) }

    context 'when write_followings scope authorized' do
      before { authorize!(:write_followings) }
      let(:following) { Fabricate(:following, :public => false) }
      let(:data) do
        data = following.attributes
        data[:groups] = ['group-id-1', 'group-id-2']
        data[:entity] = "https://entity-name.example.org"
        data[:public] = true
        data[:profile] = { 'type-uri' => { 'foo' => 'bar' } }
        data[:licenses] = ['https://license.example.org']
        data[:mac_key_id] = SecureRandom.hex(4)
        data[:mac_key] = SecureRandom.hex(16)
        data[:mac_algorithm] = 'hmac-sha-1'
        data[:mac_timestamp_delta] = Time.now.to_i
        data
      end

      it 'should update following' do
        json_put "/followings/#{following.public_id}", data, env
        expect(last_response.status).to eql(200)

        whitelist = [:groups, :entity, :public, :profile, :licenses]
        blacklist = [:mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta]

        following.reload
        whitelist.each { |key|
          expect(following.send(key).to_json).to eql(data[key].to_json)
        }

        blacklist.each { |key|
          expect(following.send(key).to_json).to_not eql(data[key].to_json)
        }
      end

      context 'when write_secrets scope authorized' do
        before {
          authorize!(:write_followings, :write_secrets)
        }

        it 'should update following mac key' do
          json_put "/followings/#{following.public_id}", data, env
          expect(last_response.status).to eql(200)

          whitelist = [:groups, :entity, :public, :profile, :licenses]
          whitelist.concat [:mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta]

          following.reload
          whitelist.each { |key|
            expect(following.send(key).to_json).to eql(data[key].to_json)
          }
        end
      end

      it 'should return 404 unless following with :id exists' do
        json_put '/followings/invalid-id', params, env
        expect(last_response.status).to eql(404)
      end
    end

    context 'when write_followings scope not authorized' do
      it 'should return 403' do
        json_put '/followings/following-id', params, env
        expect(last_response.status).to eql(403)
      end
    end
  end

  describe 'DELETE /followings/:id' do
    let!(:following) { Fabricate(:following, :remote_id => '12345678') }
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }

    context 'when write_followings scope authorized' do
      before { authorize!(:write_followings) }

      context 'when exists' do
        it 'should delete following' do
          http_stubs.delete("/followers/#{following.remote_id}") { |env|
            [200, {} ['']]
          }
          TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
          expect(lambda { delete "/followings/#{following.public_id}", params, env }).
            to change(TentD::Model::Following, :count).by(-1)
          http_stubs.verify_stubbed_calls

          deleted_following = TentD::Model::Following.unfiltered.first(:id => following.id)
          expect(deleted_following).to_not be_nil
          expect(deleted_following.deleted_at).to_not be_nil
        end
      end

      context 'when does not exist' do
        it 'should return 404' do
          expect(lambda { delete "/followings/invalid-id", params, env }).
            to_not change(TentD::Model::Following, :count)
          expect(last_response.status).to eql(404)
        end
      end
    end

    context 'when write_followings scope unauthorized' do
      it 'should return 403' do
        expect(lambda { delete "/followings/invalid-id", params, env }).
          to_not change(TentD::Model::Following, :count)
        expect(last_response.status).to eql(403)
      end
    end
  end

  describe 'GET /followings/:id/*' do
    let(:following) { Fabricate(:following) }
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
    before { authorize!(:read_followings) }

    it 'should proxy the request to the following server' do
      http_stubs.get('/profile') { |env|
        expect(env[:request_headers]['Authorization']).to match(/#{following.mac_key_id}/)
        [200, { 'Content-Type' => 'application/json' }, '{}']
      }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      json_get("/followings/#{following.public_id}/profile", {}, env)
      expect(last_response.status).to eql(200)
      expect(last_response.body).to eql('{}')
      expect(last_response.headers['Content-Type']).to eql('application/json')
      http_stubs.verify_stubbed_calls
    end
  end

  describe 'GET /follow' do
    before { Fabricate(:app_authorization, :app => Fabricate(:app), :scopes => %w{ follow_ui }, :follow_url => 'https://example.com/follow') }

    it 'should redirect to app authoirization with follow_ui scope and follow_url' do
      get '/follow', { :entity => 'https://johnsmith.example.org' }, env
      expect(last_response.status).to eql(302)
      expect(last_response.headers['Location']).to eql("https://example.com/follow?entity=https%3A%2F%2Fjohnsmith.example.org")
    end
  end
end
