require 'spec_helper'

describe TentD::Model::NotificationSubscription do
  it 'should parse view from type URI before save' do
    instance = described_class.new(:type => "https://tent.io/types/post/photo/v0.1.x#meta")
    expect(instance.save).to be_true
    expect(instance.reload.type_view).to eq('meta')
  end

  it 'should parse version from type URI' do
    instance = described_class.new(:type => "https://tent.io/types/post/photo/v0.1.x#meta")
    expect(instance.type_version).to eq("0.1.x")
  end

  it 'should parse view from type URI' do
    instance = described_class.new(:type => "https://tent.io/types/post/photo/v0.1.x#meta")
    expect(instance.type_view).to eq('meta')
  end

  it 'should remove version and view from type' do
    instance = described_class.create(:type => "https://tent.io/types/post/photo/v0.1.x#meta")
    expect(instance.type.base).to eq('https://tent.io/types/post/photo')
  end

  it 'should create if type is all' do
    expect(lambda {
      described_class.create(:type => 'all')
    }).to change(described_class, :count).by(1)
  end

  it 'should require type_version unless type_base set to all' do
    expect(lambda {
      described_class.create(:type => 'https://tent.io/types/post/photo')
    }).to_not change(described_class, :count)
  end

  context "notifications" do
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:post) { Fabricate(:post) }
    before { TentD::Model::NotificationSubscription.all.destroy! }

    context "to everyone" do
      let!(:subscription) { Fabricate(:notification_subscription, :follower => Fabricate(:follower)) }

      it 'should notify about a post' do
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
        http_stubs.post('/posts') { [200, {}, nil] }

        described_class.notify_all(post.type, post.id)
        http_stubs.verify_stubbed_calls
      end
    end

    context "to a follower" do
      let(:subscription) { Fabricate(:notification_subscription, :follower => Fabricate(:follower)) }

      it 'should notify about a post' do
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
        http_stubs.post('/posts') { [200, {}, nil] }
        expect(subscription.notify_about(post.id)).to be_true
      end
    end

    context "to an app" do
      let(:subscription) { Fabricate(:notification_subscription, :app_authorization => Fabricate(:app_authorization, :app => Fabricate(:app))) }

      it 'should notify about a post' do
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
        http_stubs.post('/notifications') { [200, {}, nil] }
        expect(subscription.notify_about(post.id)).to be_true
      end
    end

    context ".notify_entity(entity, post_id)" do
      before {
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      }

      let(:post) { Fabricate(:post) }
      let(:path_prefix) { URI(server_url).path }

      notification_examples = proc do
        it "should send notification" do
          http_stubs.post("#{path_prefix}/posts") { |env|
            expect_server(env, server_url)
            [200, {}, '']
          }

          described_class.notify_entity(entity, post.id)

          http_stubs.verify_stubbed_calls
        end
      end

      context "entity exists as follower" do
        let(:entity) { 'https://example.com/johndoe' }
        let(:server_url) { 'https://example.org/johndoe/tent' }
        before { Fabricate(:follower, :entity => entity, :server_urls => server_url) }

        context &notification_examples
      end

      context "entity exists as following" do
        let(:entity) { 'https://example.com/alexsmith' }
        let(:server_url) { 'https://alex.example.org/tent' }
        before { Fabricate(:following, :entity => entity, :server_urls => server_url) }

        context &notification_examples
      end

      context "entity is not a follower or following" do
        let(:entity) { 'https://bob.example.com' }
        let(:server_url) { 'https://bob.example.org/tent' }

        let(:link_header) { %(<#{server_url}/profile>; rel="%s") % TentClient::PROFILE_REL }
        let(:tent_profile) { %({"https://tent.io/types/info/core/v0.1.0":{"licenses":["http://creativecommons.org/licenses/by/3.0/"],"entity":"#{entity}","servers":["#{server_url}"]}}) }

        let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
        let(:client) { TentClient.new(nil, :faraday_adapter => [:test, http_stubs]) }

        before do 
          http_stubs.head("/") { |env|
            expect_server(env, entity)
            [200, { 'Link' => link_header }, '']
          }
          http_stubs.get("#{path_prefix}/profile") { |env|
            expect_server(env, server_url)
            [200, { 'Content-Type' => TentClient::MEDIA_TYPE }, tent_profile]
          }
        end

        context 'with discovery', &notification_examples
      end
    end
  end
end
