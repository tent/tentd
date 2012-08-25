require 'spec_helper'

class TentServer::Model::Post; end

describe TentServer::API::Posts::GetOne do
  let(:instance) { described_class.new({}) }

  it "should get single post and set response in env" do
    post = stub(id: 1)
    TentServer::Model::Post.expects(:get).with(post.id).returns(post)

    env = instance.action({}, { :post_id => post.id }, {})
    expect(env['response']).to eq(post)
  end
end
