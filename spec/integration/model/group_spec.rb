require 'spec_helper'

describe TentServer::Model::Group do
  it 'should set random_uid for id' do
    group = Fabricate(:group)
    expect(group.id).to be_a(String)
  end

  it 'should never set duplicate uid' do
    first_group = Fabricate(:group)
    group = Fabricate(:group, :id => first_group.id)
    expect(group).to be_saved
    expect(group.id).to_not eq(first_group.id)
  end
end
