require 'spec_helper'

describe "HEAD /" do
  def app
    TentD::API.new
  end

  it "returns link header pointing to meta post" do
    meta_post = current_user.meta_post

    expect(TentClient::Discovery.discover(client, current_user.entity)).to eql('post' => TentD::Utils::Hash.stringify_keys(meta_post.as_json))
  end
end
