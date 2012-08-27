require 'spec_helper'

describe TentServer::TentVersion do
  describe '.from_uri' do
    it 'should parse version from URI' do
      uri = URI("https://tent.io/types/posts/photo/v0.x.x#meta")
      expect(described_class.from_uri(uri)).to eq(described_class.new("0.x.x"))
    end
  end

  describe '#to_s' do
    it 'should return version string' do
      expect(described_class.new("0.1.x").to_s).to eq("0.1.x")
    end
  end

  it 'should equal another TentVersion' do
    expect(described_class.new("0.1.0") == described_class.new("0.1.0")).to be_true
  end

  it 'should equal a version String' do
    expect(described_class.new("0.1.0") == "0.1.0").to be_true
  end

  it 'should not equal an incompatible TentVersion' do
    expect(described_class.new("0.2.0") == described_class.new("0.1.x")).to be_false
  end

  it 'should equal fuzzy versions' do
    expect(described_class.new("0.x.x") == described_class.new("0.2.0")).to be_true
    expect(described_class.new("0.2.1") == described_class.new("0.2.x")).to be_false
    expect(described_class.new("x.x.x") == described_class.new("1.2.9")).to be_true
    expect(described_class.new("0.1.x") == described_class.new("0.1.0")).to be_true
    expect(described_class.new("0.1.x") == described_class.new("0.1.9")).to be_true
  end
end
