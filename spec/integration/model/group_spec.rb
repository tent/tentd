require 'spec_helper'

describe TentServer::Model::Group do
  it 'should set random_uid for public_uid' do
    group = Fabricate(:group)
    expect(group.public_uid).to be_a(String)
  end

  it 'should never set duplicate public_uid' do
    first_group = Fabricate(:group)
    group = Fabricate(:group, :public_uid => first_group.public_uid)
    expect(group).to be_saved
    expect(group.public_uid).to_not eq(first_group.public_uid)
  end

  describe '#as_json' do
    it 'should set id to public_uid' do
      group = Fabricate(:group)
      expect(group.as_json[:id]).to eq(group.public_uid)
      expect(group.as_json).to_not have_key(:public_uid)
    end
  end
end
