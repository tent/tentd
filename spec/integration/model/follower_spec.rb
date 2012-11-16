require 'spec_helper'

describe TentD::Model::Follower do

  describe '.update_entity' do
    let(:old_entity) { 'https://old-entity.example.org' }
    let(:new_entity) { 'https://new-entity.example.org' }
    let(:follower) { Fabricate(:follower, :entity => old_entity) }
    let(:updated_profile) {
      {
        TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI => {
          "entity" => new_entity,
          "servers" => ["#{new_entity}/tent"]
        }
      }
    }
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
    before { TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs]) }

    it 'should update follower entity' do
      http_stubs.get('/profile') {
        [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, updated_profile.to_json]
      }

      TentD::Model::Follower.update_entity(follower.id)
      expect(follower.reload.entity).to eq(new_entity)
    end

    it 'should update posts authored by follower' do
      http_stubs.get('/profile') {
        [200, { 'Content-Type' => TentD::API::MEDIA_TYPE }, updated_profile.to_json]
      }
      post = Fabricate(:post, :entity => old_entity, :original => false)

      TentD::Model::Follower.update_entity(follower.id)
      expect(post.reload.entity).to eq(new_entity)
    end
  end

  describe 'create_follower' do
    let(:group) { Fabricate(:group, :name => 'GroupA') }
    let(:following) { Fabricate(:following) }
    let(:other_follower) { Fabricate(:follower) }
    let(:attributes) do
      Hashie::Mash.new(
        :entity => "http://test.example.com",
        :permissions => {
          :groups => [{ :id => group.public_id }],
          :entities => {
            following.entity => true,
            other_follower.entity => true
          },
          :public => true
        },
        :id => 'public-id',
        :notification_path => '/notifications',
        :created_at => 1350663594,
        :updated_at => 1350666333,
        :mac_key_id => 'mac-key-id',
        :mac_key => 'mac_key',
        :mac_algorithm => 'hmac-sha-256',
        :groups => [],
        :profile => {
          :"https://tent.io/types/info/basic/v0.1.0" => {
            :name => "Mr. Eldridge Marvin",
            :permissions => {
              :public => true
            }
          },
          :"https://tent.io/types/info/core/v0.1.0" => {
            :entity => "http://test.example.com",
            :servers => %w( http://test.example.com/tent http://tent.example.org ),
            :permissions => {
              :public => true
            }
          }
        }
      )
    end

    context 'when write_followers and write_secrets authorized' do
      let(:authorized_scopes) { [:write_followers, :write_secrets] }
      before { TentD::Model::Follower.all.destroy }
      before { TentD::Model::Following.all.destroy }

      it 'should create permissions' do
        expect(lambda {
          follower = described_class.create_follower(attributes, authorized_scopes)
        }).to change(TentD::Model::Permission, :count).by(3)
      end
    end
  end

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
            TentD::Model::Permission.create(
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
    end
  end

  describe 'fetch_all(params)' do
    let(:params) { Hash.new }

    it 'should return all followers' do
      public_follower = Fabricate(:follower, :public => true)
      private_follower = Fabricate(:follower, :public => false)

      max_count = TentD::Model::Follower.count
      with_constants "TentD::API::MAX_PER_PAGE" => max_count, "TentD::API::PER_PAGE" => max_count do
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
          TentD::Model::Follower.all.destroy
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

        it 'should never return more than TentD::API::MAX_PER_PAGE followers' do
          limit = 1
          Fabricate(:follower, :public => false)

          params['limit'] = limit

          with_constants "TentD::API::MAX_PER_PAGE" => 0 do
            res = described_class.fetch_all(params)
            expect(res.size).to eq(0)
          end
        end
      end

      context 'without [:limit]' do
        it 'should never return more than TentD::API::MAX_PER_PAGE followers' do
          Fabricate(:follower, :public => false)

          with_constants "TentD::API::MAX_PER_PAGE" => 0 do
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
            TentD::Model::Permission.create(
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
          if current_auth.kind_of?(TentD::Model::Follower)
            TentD::Model::Follower.all(:id.not => current_auth.id).destroy!
            follower = current_auth
          else
            TentD::Model::Follower.all.destroy!
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

        it 'should never return more than TentD::API::MAX_PER_PAGE followers' do
          with_constants "TentD::API::MAX_PER_PAGE" => 0 do
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
        it 'should only return TentD::API::PER_PAGE number of followers' do
          with_constants "TentD::API::PER_PAGE" => 1 do
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
        max_results = TentD::Model::Follower.count + 100
        with_constants "TentD::API::MAX_PER_PAGE" => max_results, "TentD::API::PER_PAGE" => max_results do
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

        TentD::Model::Permission.create(
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
    end
  end

  describe "#as_json" do
    let(:follower) { Fabricate(:follower) }
    let(:public_attributes) do
      {
        :id => follower.public_id,
        :entity => follower.entity,
        :permissions => { :public => true }
      }
    end

    context 'without options' do
      it 'should return public attributes' do
        expect(follower.as_json).to eq(public_attributes)
      end
    end

    context 'with options[:mac]' do
      it 'should return mac key' do
        expect(follower.as_json(:mac => true)).to eq(public_attributes.merge(
          :mac_key_id => follower.mac_key_id,
          :mac_key => follower.mac_key,
          :mac_algorithm => follower.mac_algorithm
        ))
      end
    end

    context 'with options[:app]' do
      it 'should return additional attributes' do
        expect(follower.as_json(:app => true)).to eq(public_attributes.merge(
          :profile => follower.profile,
          :licenses => follower.licenses,
          :types => [],
          :created_at => follower.created_at.to_time.to_i,
          :updated_at => follower.updated_at.to_time.to_i,
          :notification_path => follower.notification_path
        ))
      end
    end

    context 'with options[:self]' do
      it 'should return licenses and types' do
        expect(follower.as_json(:self => true)).to eq(public_attributes.merge(
          :licenses => follower.licenses,
          :types => [],
          :notification_path => follower.notification_path
        ))
      end
    end

    context 'with options[:groups]' do
      it 'should return groups' do
        expect(follower.as_json(:groups => true)).to eq(public_attributes.merge(
          :groups => follower.groups.uniq
        ))
      end
    end
  end
end
