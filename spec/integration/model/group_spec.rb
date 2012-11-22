require 'spec_helper'

describe TentD::Model::Group do
  let(:group) { Fabricate(:group) }

  it 'should set random_uid for public_id' do
    expect(group.public_id).to be_a(String)
  end

  describe '#as_json' do
    let(:public_attributes) do
      {
        :id => group.public_id,
        :name => group.name
      }
    end

    it 'should return public attributes' do
      expect(group.as_json).to eq(public_attributes)
    end

    context 'with options[:app]' do
      it 'should expose timestamps' do
        expect(group.as_json(:app => true)).to eq(public_attributes.merge(
          :created_at => group.created_at.to_time.to_i,
          :updated_at => group.updated_at.to_time.to_i
        ))
      end
    end
  end
end
