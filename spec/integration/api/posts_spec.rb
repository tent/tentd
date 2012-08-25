require 'spec_helper'

describe TentServer::API::Posts do
  def app
    TentServer::API.new
  end

  describe 'GET /posts/:post_id' do
    it "should find existing post" do
      post = Fabricate(:post)
      get "/posts/#{post.id}"
      expect(last_response.body).to eq(post.to_json)
    end
  end
end
