require 'spec_helper'

describe TentServer::Model::NotificationSubscription do
  it 'should parse view from type URI before save' do
    instance = described_class.new(:type => URI("https://tent.io/types/posts/photo/v0.1.x#meta"))
    expect(instance.save).to be_true
    expect(instance.reload.view).to eq('meta')
  end

  it 'should parse version from type URI' do
    instance = described_class.new(:type => URI("https://tent.io/types/posts/photo/v0.1.x#meta"))
    expect(instance.version).to eq("0.1.x")
  end
end
