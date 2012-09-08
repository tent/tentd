require 'spec_helper'

describe TentD::Model::NotificationSubscription do
  it 'should parse view from type URI before save' do
    instance = described_class.new(:type => "https://tent.io/types/posts/photo/v0.1.x#meta")
    expect(instance.save).to be_true
    expect(instance.reload.view).to eq('meta')
  end

  it 'should parse version from type URI' do
    instance = described_class.new(:type => "https://tent.io/types/posts/photo/v0.1.x#meta")
    expect(instance.version).to eq("0.1.x")
  end

  it 'should parse view from type URI' do
    instance = described_class.new(:type => "https://tent.io/types/posts/photo/v0.1.x#meta")
    expect(instance.view).to eq('meta')
  end

  it 'should remove version and view from type' do
    instance = described_class.create(:type => "https://tent.io/types/posts/photo/v0.1.x#meta")
    expect(instance.type).to eq('https://tent.io/types/posts/photo')
  end

  context "notifications" do
    let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:post) { Fabricate(:post) }

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
  end
end
