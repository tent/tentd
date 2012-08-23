require 'spec_helper'

describe Tent::Server::API do
  def app
    Tent::Server::API
  end

  describe "GET /foo" do
    it "works" do
      get "/foo"
      last_response.status.should == 404
    end
  end
end

