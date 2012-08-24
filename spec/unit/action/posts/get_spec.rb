require 'spec_helper'

class TentServer::Model::Post; end

describe TentServer::Action::Posts::Get do
  let(:app) { lambda { |env| env } }
  let(:post_class) { TentServer::Model::Post }

  context "get single post" do
    let(:instance) { described_class.new(app, :get_one) }

    it "should set tent.post in env" do
      post = stub(id: 1)
      post_class.expects(:get).with(post.id).returns(post)

      env = instance.call('post_id' => post.id)
      expect(env['tent.post']).to eq(post)
    end
  end
end
