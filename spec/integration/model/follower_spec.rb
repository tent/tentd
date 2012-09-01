require 'spec_helper'

describe TentServer::Model::Follower do
  describe 'find_with_permissions(id, current_auth)' do
    public_expectations = proc do
      it 'should return follower if public' do
        follower = Fabricate(:follower, :public => true)
        response = described_class.find_with_permissions(follower.id, current_auth)
        expect(response).to eq(follower)
      end

      it 'should return nil if not public' do
        follower = Fabricate(:follower, :public => false)
        response = described_class.find_with_permissions(follower.id, current_auth)
        expect(response).to be_nil
      end
    end

    context 'without current_auth' do
      let(:current_auth) { nil }

      context '', &public_expectations
    end

    context 'with current_auth' do
      current_auth_expectations = proc do
        context 'when has permission' do
          it 'should return follower' do
            follower = Fabricate(:follower, :public => false)
            TentServer::Model::Permission.create(
              :follower_visibility_id => follower.id, current_auth.permissible_foreign_key => current_auth.id)

            response = described_class.find_with_permissions(follower.id, current_auth)
            expect(response).to eq(follower)
          end
        end

        context 'when does not have permission' do
          context '', &public_expectations
        end
      end

      context 'when Follower' do
        let(:current_auth) { Fabricate(:follower) }

        context '', &current_auth_expectations
      end

      context 'when AppAuthorization' do
        let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

        context '', &current_auth_expectations
      end
    end
  end

  describe 'fetch_all(params)' do
    let(:params) { Hash.new }

    it 'should return all followers' do
      public_follower = Fabricate(:follower, :public => true)
      private_follower = Fabricate(:follower, :public => false)

      max_count = TentServer::Model::Follower.count
      with_constants "TentServer::API::MAX_PER_PAGE" => max_count, "TentServer::API::PER_PAGE" => max_count do
        res = described_class.fetch_all(params)
        expect(res).to include(public_follower)
        expect(res).to include(private_follower)
      end
    end

    context 'with params' do
      context '[:since_id]' do
        it 'should only return followers with id > :since_id' do
          since_follower = Fabricate(:follower, :public => false)
          follower = Fabricate(:follower, :public => false)

          params['since_id'] = since_follower.id

          res = described_class.fetch_all(params)
          expect(res).to eq([follower])
        end
      end

      context '[:before_id]' do
        it 'should only return followers with id < :since_id' do
          TentServer::Model::Follower.all.destroy
          follower = Fabricate(:follower, :public => false)
          before_follower = Fabricate(:follower, :public => false)

          params['before_id'] = before_follower.id

          res = described_class.fetch_all(params)
          expect(res).to eq([follower])
        end
      end

      context '[:limit]' do
        it 'should only return :limit number of followers' do
          limit = 1
          0.upto(limit) { Fabricate(:follower, :public => false) }

          params['limit'] = limit

          res = described_class.fetch_all(params)
          expect(res.size).to eq(limit)
        end

        it 'should never return more than TentServer::API::MAX_PER_PAGE followers' do
          limit = 1
          Fabricate(:follower, :public => false)

          params['limit'] = limit

          with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
            res = described_class.fetch_all(params)
            expect(res.size).to eq(0)
          end
        end
      end

      context 'without [:limit]' do
        it 'should never return more than TentServer::API::MAX_PER_PAGE followers' do
          Fabricate(:follower, :public => false)

          with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
            res = described_class.fetch_all(params)
            expect(res.size).to eq(0)
          end
        end
      end
    end
  end

  describe 'fetch_with_permissions(params, current_auth)' do
    let(:params) { Hash.new }
    let(:authorize_folower) { false }

    with_params = proc do
      before do
        if current_auth && authorize_folower
          @authorize_folower = lambda do |follower|
            TentServer::Model::Permission.create(
              :follower_visibility_id => follower.id,
              current_auth.permissible_foreign_key => current_auth.id
            )
          end
        end
      end

      context '[:since_id]' do
        it 'should only return followers with id > :since_id' do
          since_follower = Fabricate(:follower, :public => !authorize_folower)
          follower = Fabricate(:follower, :public => !authorize_folower)

          params['since_id'] = since_follower.id

          if authorize_folower
            [since_follower, follower].each { |f| @authorize_folower.call(f) }
          end

          response = described_class.fetch_with_permissions(params, current_auth)
          expect(response).to eq([follower])
        end
      end

      context '[:before_id]' do
        it 'should only return followers with id < :before_id' do
          if current_auth.kind_of?(TentServer::Model::Follower)
            TentServer::Model::Follower.all(:id.not => current_auth.id).destroy!
            follower = current_auth
          else
            TentServer::Model::Follower.all.destroy!
            follower = Fabricate(:follower, :public => !authorize_folower)
          end

          before_follower = Fabricate(:follower, :public => !authorize_folower)

          params['before_id'] = before_follower.id

          if authorize_folower
            [before_follower, follower].each { |f| @authorize_folower.call(f) }
          end

          response = described_class.fetch_with_permissions(params, current_auth)
          expect(response).to eq([follower])
        end
      end

      context '[:limit]' do
        it 'should only return :limit number of followers' do
          limit = 1
          followers = 0.upto(limit).map { Fabricate(:follower, :public => !authorize_folower) }

          if authorize_folower
            followers.each { |f| @authorize_folower.call(f) }
          end

          params['limit'] = limit

          response = described_class.fetch_with_permissions(params, current_auth)
          expect(response.size).to eq(limit)
        end

        it 'should never return more than TentServer::API::MAX_PER_PAGE followers' do
          with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
            followers = [Fabricate(:follower, :public => !authorize_folower)]

            if authorize_folower
              followers.each { |f| @authorize_folower.call(f) }
            end

            response = described_class.fetch_with_permissions(params, current_auth)
            expect(response.size).to eq(0)
          end
        end
      end

      context 'without [:limit]' do
        it 'should only return TentServer::API::PER_PAGE number of followers' do
          with_constants "TentServer::API::PER_PAGE" => 1 do
            followers = 2.times.map { Fabricate(:follower, :public => !authorize_folower) }

            if authorize_folower
              followers.each { |f| @authorize_folower.call(f) }
            end

            response = described_class.fetch_with_permissions(params, current_auth)
            expect(response.size).to eq(1)
          end
        end
      end
    end

    public_expectations = proc do
      it 'should only return public followers' do
        max_results = TentServer::Model::Follower.count + 100
        with_constants "TentServer::API::MAX_PER_PAGE" => max_results, "TentServer::API::PER_PAGE" => max_results do
          public_follower = Fabricate(:follower, :public => true)
          private_follower = Fabricate(:follower, :public => false)

          response = described_class.fetch_with_permissions(params, current_auth)
          expect(response).to include(public_follower)
          expect(response).to_not include(private_follower)
        end
      end

      context 'with params', &with_params
    end

    context 'without current_auth' do
      let(:current_auth) { nil }

      context '', &public_expectations
    end

    current_auth_expectations = proc do
      context 'when has permissions' do
        it 'should return permissible and public followers' do
        public_follower = Fabricate(:follower, :public => true)
        private_follower = Fabricate(:follower, :public => false)

        TentServer::Model::Permission.create(
          :follower_visibility_id => private_follower.id,
          current_auth.permissible_foreign_key => current_auth.id
        )

        response = described_class.fetch_with_permissions(params, current_auth)
        expect(response).to include(public_follower)
        expect(response).to include(private_follower)
        end

        context 'with params' do
          context 'when private' do
            let(:authorize_folower) { true }
            context '', &with_params
          end

          context 'when public', &with_params
        end
      end

      context 'when does not have permissions', &public_expectations
    end

    context 'with current_auth' do
      context 'when Follower' do
        let(:current_auth) { Fabricate(:follower) }

        context '', &current_auth_expectations
      end

      context 'when AppAuthorization' do
        let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

        context '', &current_auth_expectations
      end
    end
  end

  describe "#as_json" do
    it "should replace id with public_uid" do
      post = Fabricate(:post)
      expect(post.as_json[:id]).to eq(post.public_uid)
    end

    it "should not add id to returned object if excluded" do
      post = Fabricate(:post)
      expect(post.as_json(:exclude => :id)).to_not have_key(:id)
    end
  end
end
