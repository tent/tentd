require 'spec_helper'

describe TentServer::API do
  def app
    TentServer::API
  end

  describe "GET /foo" do
    it "works" do
      get "/foo"
      last_response.status.should == 404
    end
  end
end

