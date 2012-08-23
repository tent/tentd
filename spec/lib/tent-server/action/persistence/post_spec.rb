require File.expand_path("../../../../../../lib/tent-server/action/persistence/post", __FILE__)
require 'mocha_standalone'

class Tent::Server::Post; end

describe Tent::Server::Action::Persistence::Post do
  let(:app) { lambda { |env| env } }
  let(:post_class) { Tent::Server::Post }

  context "get single post" do
    let(:instance) { described_class.new(app, :get) }

    it "should set tent.post in env" do
      post = stub(id: 1)
      post_class.expects(:find).with(post.id).returns(post)

      env = instance.call('post_id' => post.id)
      expect(env['tent.post']).to eq(post)
    end
  end
end
