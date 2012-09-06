require 'spec_helper'

describe TentD::Model::Following do
  describe "#as_json" do
    let(:following) { Fabricate(:following) }
    let(:public_attributes) do
      {
        :id => following.public_id,
        :remote_id => following.remote_id,
        :entity => following.entity,
        :permissions => { :public => following.public }
      }
    end

    context 'without options' do
      it 'should return public attributes' do
        expect(following.as_json).to eq(public_attributes)
      end
    end

    context 'with options[:mac]' do
      it 'should return mac key' do
        expect(following.as_json(:mac => true)).to eq(public_attributes.merge(
          :mac_key_id => following.mac_key_id,
          :mac_key => following.mac_key,
          :mac_algorithm => following.mac_algorithm
        ))
      end
    end

    context 'with options[:groups]' do
      it 'should return groups' do
        expect(following.as_json(:groups => true)).to eq(public_attributes.merge(
          :groups => following.groups
        ))
      end
    end

    context 'with options[:permissions]' do
      let(:follower) { Fabricate(:follower) }
      let(:group) { Fabricate(:group) }
      let(:entity_permission) { Fabricate(:permission, :follower_access => follower) }
      let(:group_permission) { Fabricate(:permission, :group => group) }
      let(:following) { Fabricate(:following, :permissions => [group_permission, entity_permission]) }

      it 'should return detailed permissions' do
        expect(following.as_json(:permissions => true)).to eq(public_attributes.merge(
          :permissions => {
            :public => following.public,
            :groups => [group.public_id],
            :entities => {
              follower.entity => true
            }
          }
        ))
      end
    end

    context 'with options[:app]' do
      it 'should return additional attribtues' do
        expect(following.as_json(:app => true)).to eq(public_attributes.merge(
          :profile => following.profile,
          :licenses => following.licenses,
          :updated_at => following.updated_at.to_time.to_i,
          :created_at => following.updated_at.to_time.to_i
        ))
      end
    end
  end
end
