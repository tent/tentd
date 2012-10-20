require 'spec_helper'

describe TentD::Model::ProfileInfo do
  context '.update_profile' do
    let(:core_profile_type) { 'https://tent.io/types/info/core/v0.1.0' }
    let(:entity) { 'http://other.example.com' }
    let(:other_entity) { 'http://someone.example.com' }

    context 'when entity updated' do
      it 'should update original posts with new entity' do
        profile_info = Fabricate(:profile_info, :public => true, :type => core_profile_type)
        post = Fabricate(:post, :entity => 'http://example.com', :original => true)
        other_post = Fabricate(:post, :entity => other_entity, :original => false)

        described_class.update_profile(core_profile_type, {
          :entity => entity
        })

        post = TentD::Model::Post.get(post.id)
        other_post = TentD::Model::Post.get(other_post.id)
        expect(post.entity).to eq(entity)
        expect(other_post.entity).to eq(other_entity)
      end
    end
  end
end
