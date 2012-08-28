require 'spec_helper'

describe TentServer::API::AuthenticationFinalize do
  def app
    TentServer::API.new
  end

  it "should set current_auth" do
    instance = stub(:mac_timestamp_delta => 1346171050)
    env = Hashie::Mash.new({
      "potential_auth" => instance,
      'hmac' => { 'ts' => "1336363200", 'verified' => true }
    })
    described_class.new(app).call(env)
    expect(env["current_auth"]).to eq(instance)
  end

  it "should set mac_timestamp_delta on current_auth" do
    now = Time.now; Time.stubs(:now).returns(now)
    delta = now.to_i - 1336363200
    instance = stub(:mac_timestamp_delta => nil)
    env = Hashie::Mash.new({
      "potential_auth" => instance,
      'hmac' => { 'ts' => "1336363200", 'verified' => true }
    })
    instance.expects(:update).with(:mac_timestamp_delta => delta).returns(true)
    described_class.new(app).call(env)
  end

  it "should not set mac_timestamp_delta on current_auth if already set" do
    instance = stub(:mac_timestamp_delta => 1346171050)
    env = Hashie::Mash.new({
      "potential_auth" => instance,
      'hmac' => { 'ts' => "1336363200", 'verified' => true }
    })
    instance.expects(:update).never
    described_class.new(app).call(env)
  end

  it 'should do nothing unless env.hmac.verified present' do
    env = Hashie::Mash.new({ "potential_auth" => stub(:mac_timestamp_delta => 1346171050) })
    described_class.new(app).call(env)
    expect(env.current_auth).to be_nil
  end
end
