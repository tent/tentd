require 'spec_helper'

describe TentD::TentType do
  let(:instance) { described_class.new("https://tent.io/types/post/status/v0.1.0#meta") }

  it 'should parse version' do
    expect(instance.version).to eq('0.1.0')
  end

  it 'should parse view' do
    expect(instance.view).to eq('meta')
  end

  it 'should parse base type uri' do
    expect(instance.uri).to eq('https://tent.io/types/post/status')
  end
end
