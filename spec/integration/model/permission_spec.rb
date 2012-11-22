require 'spec_helper'

describe TentD::Model::Permission do
  describe '.copy(from, to)' do
    let!(:group) { Fabricate(:group) }

    common_to_post = proc {
      context 'when to post' do
        let(:to) { Fabricate(:post) }

        it 'should create identical permission associated with to post' do
          expect(lambda {
            described_class.copy(from, to)
          }).to change(to.permissions_dataset, :count).by(1)
          expect(to.permissions.first.group_public_id).to eq(from.permissions.first.group_public_id)
        end
      end
    }

    context 'when from post' do
      let!(:from) { Fabricate(:post) }
      let!(:permission) { Fabricate(:permission, :post => from, :group_public_id => group.public_id) }

      context &common_to_post
    end

    context 'when from following' do
      let!(:from) { Fabricate(:following) }
      let!(:permission) { Fabricate(:permission, :following => from, :group_public_id => group.public_id) }

      context &common_to_post
    end

    context 'when from follower' do
      let!(:from) { Fabricate(:follower) }
      let!(:permission) { Fabricate(:permission, :follower_visibility => from, :group_public_id => group.public_id) }

      context 'when to post' do
        let(:to) { Fabricate(:post) }

        it 'should create identical permission associated with to post' do
          expect(lambda {
            described_class.copy(from, to)
          }).to change(to.permissions_dataset, :count).by(1)
          expect(to.permissions.first.group_public_id).to eq(from.visibility_permissions.first.group_public_id)
        end
      end
    end

    context 'when from profile_info' do
      let!(:from) { Fabricate(:profile_info) }
      let!(:permission) { Fabricate(:permission, :profile_info => from, :group_public_id => group.public_id) }

      context &common_to_post
    end
  end
end
