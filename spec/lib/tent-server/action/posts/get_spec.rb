require 'spec_helper'

class Tent::Server::Post; end

describe Tent::Server::Action::Posts::Get do
  let(:app) { lambda { |env| env } }
  let(:post_class) { Tent::Server::Post }

  context "get single post" do
    let(:instance) { described_class.new(app, :get_one) }

    it "should set tent.post in env" do
      post = stub(id: 1)
      post_class.should_receive(:find).with(post.id).and_return(post)

      env = instance.call('post_id' => post.id)
      expect(env['tent.post']).to eq(post)
    end
  end
end
