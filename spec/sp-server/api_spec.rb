require 'spec_helper'

describe SP::Server::API do
  def app
    SP::Server::API
  end

  describe "GET /foo" do
    it "works" do
      get "/foo"
      last_response.status.should == 404
    end
  end
end
