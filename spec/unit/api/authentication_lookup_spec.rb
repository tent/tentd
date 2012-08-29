require 'spec_helper'

describe TentServer::API::AuthenticationLookup do
  def app
    TentServer::API.new
  end

  let(:env) { Hashie::Mash.new({}) }
  let(:auth_header) { 'MAC id="%s:h480djs93hd8", ts="1336363200", nonce="dj83hs9s", mac="hqpo01mLJLSYDbxmfRgNMEw38Wg="' }

  it 'should parse hmac authorization header' do
    TentServer::Model::Follower.all.destroy
    follow = TentServer::Model::Follower.create(:mac_key_id => "s:h480djs93hd8")
    env['HTTP_AUTHORIZATION'] = auth_header % 's'
    described_class.new(app).call(env)
    expect(env['hmac']).to eq({
      "algorithm" => "hmac-sha-256",
      "id" => "s:h480djs93hd8",
      "ts" => "1336363200",
      "nonce" => "dj83hs9s",
      "secret" => follow.mac_key,
      "mac" => "hqpo01mLJLSYDbxmfRgNMEw38Wg="
    })
  end

  it 'should lookup server authentication model' do
    TentServer::Model::Follower.all(:mac_key_id => "s:h480djs93hd8").destroy
    follow = TentServer::Model::Follower.create(:mac_key_id => "s:h480djs93hd8")
    expect(follow.saved?).to be_true
    env['HTTP_AUTHORIZATION'] = auth_header % 's'
    described_class.new(app).call(env)
    expect(env.potential_auth).to eq(follow.reload)
    expect(env.hmac.secret).to eq(follow.mac_key)
    expect(env.hmac.algorithm).to eq(follow.mac_algorithm)
  end

  it 'should lookup app authentication model' do
    TentServer::Model::App.all.destroy
    authed_app = TentServer::Model::App.create(:mac_key_id => "a:h480djs93hd8")
    expect(authed_app.saved?).to be_true
    env['HTTP_AUTHORIZATION'] = auth_header % 'a'
    described_class.new(app).call(env)
    expect(env.potential_auth).to eq(authed_app)
    expect(env.hmac.secret).to eq(authed_app.mac_key)
    expect(env.hmac.algorithm).to eq(authed_app.mac_algorithm)
  end

  it 'should lookup user authentication model' do
    TentServer::Model::AppAuthorization.all.destroy
    authed_user = TentServer::Model::AppAuthorization.create(:mac_key_id => "u:h480djs93hd8",
                                                             :app => TentServer::Model::App.create)
    expect(authed_user.saved?).to be_true
    env['HTTP_AUTHORIZATION'] = auth_header % 'u'
    described_class.new(app).call(env)
    expect(env.potential_auth).to eq(authed_user)
    expect(env.hmac.secret).to eq(authed_user.mac_key)
    expect(env.hmac.algorithm).to eq(authed_user.mac_algorithm)
  end

  it 'should do nothing unless HTTP_AUTHORIZATION header' do
    env = {}
    described_class.new(app).call(env)
    expect(env['hmac']).to be_nil
  end
end
