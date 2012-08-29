require 'spec_helper'

describe TentServer::Model::Post do
  describe 'find_with_permissions' do
    shared_examples 'current_auth param' do |options={}|
      let(:group) { Fabricate(:group, :name => 'family') }
      let(:post) { Fabricate(:post, :public => false) }

      context 'when has permission via explicit' do
        before do
          case current_auth
          when TentServer::Model::Follower
            current_auth.access_permissions.create(:post_id => post.id)
          else
            current_auth.permissions.create(:post_id => post.id)
          end
        end

        it 'should return post' do
          returned_post = described_class.find_with_permissions(post.id, current_auth)
          expect(returned_post).to eq(post)
        end

      end

      unless options[:groups] == false
        context 'when has permission via group' do
          before do
            group.permissions.create(:post_id => post.id)
            current_auth.groups = [group.id]
            current_auth.save
          end

          it 'should return post' do
            returned_post = described_class.find_with_permissions(post.id, current_auth)
            expect(returned_post).to eq(post)
          end
        end
      end

      context 'when does not have permission' do
        it 'should return nil' do
          returned_post = described_class.find_with_permissions(post.id, current_auth)
          expect(returned_post).to be_nil
        end
      end
    end

    context 'when Follower' do
      let(:current_auth) { Fabricate(:follower, :groups => []) }

      it_behaves_like 'current_auth param'
    end

    context 'when AppAuthorization' do
      let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

      it_behaves_like 'current_auth param'
    end

    context 'when App' do
      let(:current_auth) { Fabricate(:app) }

      it_behaves_like 'current_auth param', :groups => false
    end

  end

  it "should persist with proper serialization" do
    attributes = {
      :entity => "https://example.org",
      :scope => :limited,
      :type => "https://tent.io/types/posts/status",
      :licenses => ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"],
      :content => {
        "text" => "Voluptate nulla et similique sed dignissimos ea. Dignissimos sint reiciendis voluptas. Aliquid id qui nihil illum omnis. Explicabo ipsum non blanditiis aut aperiam enim ab."
      }
    }

    post = described_class.create!(attributes)
    post = described_class.get(post.id)
    attributes.each_pair do |k,v|
      actual_value = post.send(k)
      if actual_value.is_a? Addressable::URI
        actual_value = actual_value.to_s
      end
      expect(actual_value).to eq(v)
    end
  end
end

