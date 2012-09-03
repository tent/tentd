require 'spec_helper'

describe TentD::TentVersion do
  describe '.from_uri' do
    it 'should parse version from URI' do
      uri = "https://tent.io/types/posts/photo/v0.x.x#meta"
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
    expect(described_class.new("0.2.1") == described_class.new("0.2.x")).to be_true
    expect(described_class.new("x.x.x") == described_class.new("1.2.9")).to be_true
    expect(described_class.new("0.1.x") == described_class.new("0.1.0")).to be_true
    expect(described_class.new("0.1.x") == described_class.new("0.1.9")).to be_true
    expect(described_class.new("0.2.x") == described_class.new("0.1.9")).to be_false
  end

  describe '#parts' do
    it 'should return array of version parts' do
      expect(described_class.new('0.1.0').parts).to eq([0, 1, 0])
      expect(described_class.new('0.1.x').parts).to eq([0, 1, 'x'])
    end
  end

  describe '#parts=' do
    it 'should set version from parts array' do
      version = described_class.new('0.1.x')

      version.parts = [0, 1, 0]
      expect(version.parts).to eq([0, 1, 0])

      version.parts = [0, 2, 'x']
      expect(version.parts).to eq([0, 2, 'x'])
    end
  end

  describe '#>(other_instance)' do
    it 'should return true if grater than other instance' do
      expect(described_class.new("0.2.x") > described_class.new("0.1.9")).to be_true
    end
  end

  describe '#<(other_instance)' do
    it 'should return true if less than other instance' do
      expect(described_class.new("0.1.x") < described_class.new("0.2.9")).to be_true
    end
  end
end
