require 'spec_helper'

describe TentD::Model::ProfileInfo do
  let(:core_profile_type_base) { 'https://tent.io/types/info/core' }
  let(:core_profile_type) { "#{core_profile_type_base}/v0.1.0" }
  let(:entity) { 'http://other.example.com' }
  let(:other_entity) { 'http://someone.example.com' }

  context '.update_profile' do
    context 'when entity updated' do
      it 'should update original posts with new entity' do
        profile_info = Fabricate(:profile_info, :public => true, :type => core_profile_type, :content => { :entity => 'http://example.com' })
        post = Fabricate(:post, :entity => 'http://example.com', :original => true)
        other_post = Fabricate(:post, :entity => other_entity, :original => false)
        mention = TentD::Model::Mention.create(:post_id => other_post.id, :entity => 'http://example.com')
        other_mention = TentD::Model::Mention.create(:post_id => post.id, :entity => other_entity)

        described_class.update_profile(core_profile_type, {
          :entity => entity
        })

        post = TentD::Model::Post.first(:id => post.id)
        other_post = TentD::Model::Post.first(:id => other_post.id)
        mention = TentD::Model::Mention.first(:id => mention.id)
        other_mention = TentD::Model::Mention.first(:id => other_mention.id)
        expect(post.entity).to eq(entity)
        expect(mention.entity).to eq(entity)
        expect(other_mention.entity).to eq(other_entity)
        expect(other_post.entity).to eq(other_entity)
      end

      it 'should add previous entity to core profile' do
        TentD::Model::ProfileInfo.destroy
        profile_info = Fabricate(:profile_info, :public => true, :type => core_profile_type, :content => { :entity => 'http://example.com' })

        described_class.update_profile(core_profile_type, {
          :entity => entity
        })

        profile_info = profile_info.class.first(:type_base => core_profile_type_base)
        expect(profile_info.content['previous_entities']).to eq(['http://example.com'])

        described_class.update_profile(core_profile_type, {
          :entity => 'http://somethingelse.example.com',
          :previous_entities => ['http://example.com']
        })

        profile_info = profile_info.class.first(:type_base => core_profile_type_base)
        expect(profile_info.content['previous_entities']).to eq([entity, 'http://example.com'])
      end
    end
  end

  describe '#create_update_post' do
    context 'entity_changed' do
      it 'should notify mentioned entities' do
        profile_info = Fabricate(:profile_info, :public => true, :type => core_profile_type, :content => { :entity => entity })
        post = Fabricate(:post, :entity => entity, :original => true)
        self_mention = TentD::Model::Mention.create(:post_id => post.id, :entity => entity)
        mention = TentD::Model::Mention.create(:post_id => post.id, :entity => other_entity)

        TentD::Model::Permission.expects(:copy).at_least(1)
        TentD::Notifications.expects(:trigger).once
        TentD::Notifications.expects(:notify_entity).with(has_entry(:entity => other_entity))

        profile_info.create_update_post(:entity_changed => true, :old_entity => entity)
      end
    end
  end
end
