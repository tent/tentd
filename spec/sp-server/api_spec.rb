require 'spec_helper'

describe SP::Server::API do
  def app
    SP::Server::API
  end

  describe "POST /subscriptions" do
    it "creates a new subscription" do
      json_post '/subscriptions', :foo => 'bar'
      last_response.status.should == 201
    end
  end
end
