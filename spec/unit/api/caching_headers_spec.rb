require 'spec_helper'

describe TentD::API::Router::CachingHeaders do
  let(:app) { lambda { |env| [200, {}, ''] } }
  let(:middleware) { TentD::API::Router::CachingHeaders.new(app) }
  let(:env) { Hashie::Mash.new }

  shared_examples 'conditional get' do
    it 'should respond with a 304 when cached' do
      status, headers, body = middleware.call env.merge('response' => response,
                                                        'HTTP_IF_MODIFIED_SINCE' => Time.now.httpdate)
      expect(status).to eq(304)
      expect(body).to be_nil
    end

    it 'should not 304 when not cached' do
      status, headers, body = middleware.call env.merge('response' => response,
                                                        'HTTP_IF_MODIFIED_SINCE' => (Time.now - 60).httpdate)
      expect(status).to eq(200)
      expect(headers['Last-Modified']).to_not be_nil
    end
  end

  shared_examples 'public response' do
    it 'should set Cache-Control to public' do
      expect(middleware.call(env.merge('response' => response))[1]['Cache-Control']).to eq('public')
    end
  end

  shared_examples 'private response' do
    it 'should set Cache-Control to private' do
      expect(middleware.call(env.merge('response' => response))[1]['Cache-Control']).to eq('private')
    end
  end

  context 'object instance with #updated_at' do
    let(:response) { stub(:updated_at => Time.now-1) }
    it_behaves_like 'conditional get'
  end

  context 'hash with "updated_at"' do
    let(:response) { { 'updated_at' => Time.now-1 } }
    it_behaves_like 'conditional get'
  end

  context 'object array with #updated_at' do
    let(:response) { [stub(:updated_at => Time.now-1), stub(:updated_at => Time.now-90)] }
    it_behaves_like 'conditional get'
  end

  context 'hash array with "updated_at"' do
    let(:response) { [{ "updated_at" => Time.now-1 }, { "updated_at" => Time.now-90 }] }
    it_behaves_like 'conditional get'
  end

  context "object that doesn't respond to #updated_at" do
    it "should return without changes" do
      expect(middleware.call(env.merge('response' => stub)).first).to eq(200)
    end
  end

  context "object that is #public" do
    let(:response) { stub(:public => true) }
    it_behaves_like 'public response'
  end

  context "object that is not #public" do
    let(:response) { stub(:public => false) }
    it_behaves_like 'private response'
  end

  context "array of #public objects" do
    let(:response) { [stub(:public => true)] * 2 }
    it_behaves_like 'public response'
  end

  context "array of public and private objects" do
    let(:response) { [stub(:public => true), stub(:public => false)] }
    it_behaves_like 'private response'
  end

  context 'hash that is "public"' do
    let(:response) { { "public" => true } }
    it_behaves_like 'public response'
  end

  context 'hash that is not "public"' do
    let(:response) { { "public" => false } }
    it_behaves_like 'private response'
  end

  context 'array of hashes that are "public"' do
    let(:response) { [{ "public" => true }]*2 }
    it_behaves_like 'public response'
  end

  context 'array of hashes that are not "public"' do
    let(:response) { [{ "public" => false }]*2 }
    it_behaves_like 'private response'
  end

  context 'hash that has public set on permissions' do
    let(:response) { { "permissions" => { "public" => true } } }
    it_behaves_like 'public response'
  end

  context 'hash that has public set to false on permissions' do
    let(:response) { { "permissions" => { "public" => false } } }
    it_behaves_like 'private response'
  end

  context 'array of hashes that have public set on permissions' do
    let(:response) { [{ "permissions" => { "public" => true } }]*2 }
    it_behaves_like 'public response'
  end

  context 'array of hashes that have public set to false on permissions' do
    let(:response) { [{ "permissions" => { "public" => false } }]*2 }
    it_behaves_like 'private response'
  end
end
