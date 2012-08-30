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

          json_get "/followings?since_id=#{since_following.id}", nil, 'current_auth' => current_auth
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

          json_get "/followings?before_id=#{before_following.id}", nil, 'current_auth' => current_auth
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
            current_auth.update(:groups => [group.id])
            TentServer::Model::Permission.create(
              :following_id => private_permissible_following.id,
              :group_id => group.id
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
    context 'without current_auth' do
    end

    context 'with current_auth' do
    end
  end

  describe 'POST /followings/:id' do
  end

  describe 'DELETE /followings/:id' do
  end
end
