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

  context "with bewit param" do
    let(:post) { TentD::Model::Credentials.generate(current_user) }

    let(:params) do
      {
        :entity => server_entity,
        :post => post.public_id
      }
    end

    let(:url_without_bewit) do
      server_meta['servers'].first['urls']['post'].gsub(/{([^}]+)}/) { URI.encode_www_form_component(params[$1.to_sym]) }
    end

    let(:bewit_input) do
      {
        :credentials => current_user.server_credentials.inject(Hash.new) { |m, (k,v)| k = k.sub(/\Ahawk_/, ''); m[k.to_sym] = v; m },
        :method => 'GET',
        :path => url_without_bewit.sub(%r{\Ahttp://[^/]+}, ''),
        :host => URI(url_without_bewit).host,
        :port => 80,
        :ts => bewit_now.to_i + ttl
      }
    end

    let(:ttl) { 86400 } # 24 hours
    let(:bewit_now) { Time.at(1366311817) }
    let(:now) { bewit_now }

    let(:bewit) { Hawk::Crypto.bewit(bewit_input) }

    let(:url) do
      uri = URI(url_without_bewit)
      uri.query = "bewit=#{bewit}"
      uri.to_s
    end

    before do
      Time.stubs(:now).returns(now)
    end

    context "when valid" do
      it "accepts the request" do
        res = client.http.get(url)
        expect(res).to be_success, "#{res.body['error']}"
      end
    end

    context "when stale timestamp" do
      let(:now) { Time.at(1366311817 + ttl + 1) }

      it "denies the request" do
        res = client.http.get(url)
        expect(res).to_not be_success
      end
    end

    context "when invalid bewit" do
      let(:bewit) { 'invalid' }
      it "denies the request" do
        res = client.http.get(url)
        expect(res).to_not be_success
      end
    end
  end
end
