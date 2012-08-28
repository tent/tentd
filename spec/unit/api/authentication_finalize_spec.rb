require 'spec_helper'

describe TentServer::API::AuthenticationFinalize do
  def app
    TentServer::API.new
  end

  let(:env) { {} }

  [:server, :app, :user].each do |type|
    it "should set current_#{type}" do
      instance = stub(:mac_timestamp_delta => 1346171050)
      env = {
        "potential_#{type}" => instance,
        'hmac' => { 'ts' => "1336363200" }
      }
      described_class.new(app).call(env)
      expect(env["current_#{type}"]).to eq(instance)
    end

    it "should set mac_timestamp_delta on current_#{type}" do
      now = Time.now; Time.stubs(:now).returns(now)
      delta = now.to_i - 1336363200
      instance = stub(:mac_timestamp_delta => nil)
      env = {
        "potential_#{type}" => instance,
        'hmac' => { 'ts' => "1336363200" }
      }
      instance.expects(:update).with(:mac_timestamp_delta => delta).returns(true)
      described_class.new(app).call(env)
    end

    it "should not set mac_timestamp_delta on current_#{type} if already set" do
      instance = stub(:mac_timestamp_delta => 1346171050)
      env = {
        "potential_#{type}" => instance,
        'hmac' => { 'ts' => "1336363200" }
      }
      instance.expects(:update).never
      described_class.new(app).call(env)
    end
  end

  it 'should do nothing unless env["hmac"] present' do
    [:server, :app, :user].each do |type|
      env = { "potential_#{type}" => stub(:mac_timestamp_delta => 1346171050) }
      described_class.new(app).call(env)
      expect(env["current_#{type}"]).to be_nil
    end
  end
end
