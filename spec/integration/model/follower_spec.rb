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
end
