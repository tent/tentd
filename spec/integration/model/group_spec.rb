require 'spec_helper'

describe TentServer::Model::Group do
  it 'should set random_uid for public_id' do
    group = Fabricate(:group)
    expect(group.public_id).to be_a(String)
  end

  it 'should never set duplicate public_id' do
    first_group = Fabricate(:group)
    group = Fabricate(:group, :public_id => first_group.public_id)
    expect(group).to be_saved
    expect(group.public_id).to_not eq(first_group.public_id)
  end

  describe '#as_json' do
    it 'should set id to public_id' do
      group = Fabricate(:group)
      expect(group.as_json[:id]).to eq(group.public_id)
      expect(group.as_json).to_not have_key(:public_id)
    end
  end
end
