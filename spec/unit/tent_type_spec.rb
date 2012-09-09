require 'spec_helper'

describe TentD::TentType do
  let(:instance) { described_class.new("https://tent.io/types/post/status/v0.1.0#meta") }

  it 'should parse version' do
    expect(instance.version).to eq('0.1.0')
  end

  it 'should parse view' do
    expect(instance.view).to eq('meta')
  end

  it 'should parse base' do
    expect(instance.base).to eq('https://tent.io/types/post/status')
  end

  it 'should reassemble URI' do
    instance.version = '0.2.0'
    expect(instance.uri.to_s).to eq("https://tent.io/types/post/status/v0.2.0#meta")
  end

  it 'should reassemble URI without version or view' do
    instance.version = nil
    instance.view = nil
    expect(instance.uri.to_s).to eq("https://tent.io/types/post/status")
  end
end
