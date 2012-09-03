require 'spec_helper'

describe TentD::API::CoreProfileData do
  let(:tent_profile_type_uri) { "https://tent.io/types/info/core/v0.1.0" }
  let(:entity_url) { "https://smith.example.com" }
  let(:another_entity_url) { "https://alex.example.org" }
  let(:data) do
    {
      "https://tent.io/types/info/core/v0.1.5" => {
        "licenses" => [],
        "entity" => entity_url,
      },
      "https://tent.io/types/info/core/v0.1.1" => {
        "licenses" => [],
        "entity" => entity_url,
      },
      "https://tent.io/types/info/core/v0.2.0" => {
        "licenses" => [],
        "entity" => entity_url,
      },
      "https://tent.io/types/info/musci/v0.1.0" => {
      }
    }
  end
  describe '#expected_version' do
    it 'should return TentVersion representing sever tent profile type uri version' do
      with_constants "TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI" => tent_profile_type_uri do
        expect(described_class.new(data).expected_version).to eq(TentD::TentVersion.new('0.1.0'))
      end
    end
  end

  describe '#versions' do
    it 'should return array of TentVersions found in data matching core info type' do
      expect(described_class.new(data).versions).to eq([
        TentD::TentVersion.new('0.1.1'),
        TentD::TentVersion.new('0.1.5'),
        TentD::TentVersion.new('0.2.0')
      ])
    end
  end

  describe '#version' do
    it 'should return closest compatible version' do
      expect(described_class.new(data).version).to eq(TentD::TentVersion.new('0.1.1'))
    end
  end

  describe '#version_key' do
    it 'should return full url of version' do
      expect(described_class.new(data).version_key).to eq("https://tent.io/types/info/core/v0.1.1")
    end
  end

  describe '#entity?(entity)' do
    it 'should return true if entity matches' do
      expect(described_class.new(data).entity?(entity_url)).to be_true
    end

    it 'should return false if entity does not match' do
      expect(described_class.new(data).entity?(another_entity_url)).to be_false
    end
  end
end
