require 'spec_helper'
require 'support/json'
require 'support/post_content_generator'

describe TentD::API::Authentication do
  def app
    TentD::API.new
  end

  let(:post_type) { 'https://tent.io/types/app/v0#' }

  let(:data) do
    {
      :type => post_type,
      :content => content_for_post_type(post_type)
    }
  end

  let(:credentials) { TentD::Model::Credentials.generate(current_user) }

  context "with Authroize header" do
    context "when valid" do
      let(:client_options) do
        {
          :credentials => TentD::Model::Credentials.slice_credentials(credentials)
        }
      end

      it "accepts the request" do
        res = client.post.create(data)
        expect(res).to be_success
      end
    end

    context "when invalid credentials" do
      let(:client_options) do
        {
          :credentials => {
            :id => 'invalid-id',
            :hawk_key => 'invalid-key',
            :hawk_algorithm => 'sha256'
          }
        }
      end

      it "denies the request" do
        res = client.post.create(data)
        expect(res).to_not be_success
        expect(res.status).to eql(403)
      end
    end
  end

  context "without Authorize header" do
    it "acts normal"
  end
end
