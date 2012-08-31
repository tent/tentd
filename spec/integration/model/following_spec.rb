require 'spec_helper'

describe TentServer::Model::Following do
  describe "#as_json" do
    it "should replace id with public_uid" do
      post = Fabricate(:post)
      expect(post.as_json[:id]).to eq(post.public_uid)
    end

    it "should not add id to returned object if excluded" do
      post = Fabricate(:post)
      expect(post.as_json(:exclude => :id)).to_not have_key(:id)
    end
  end
end
