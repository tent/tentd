require 'spec_helper'

describe TentD::Model::Following do
  describe "#as_json" do
    it "should replace id with public_id" do
      post = Fabricate(:post)
      expect(post.as_json[:id]).to eq(post.public_id)
    end

    it "should not add id to returned object if excluded" do
      post = Fabricate(:post)
      expect(post.as_json(:exclude => :id)).to_not have_key(:id)
    end
  end
end
