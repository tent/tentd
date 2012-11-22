require 'spec_helper'

describe TentD::API::AuthenticationLookup do
  def app
    TentD::API.new
  end

  let(:env) { Hashie::Mash.new({}) }
  let(:auth_header) { 'MAC id="%s:h480djs93hd8", ts="1336363200", nonce="dj83hs9s", mac="hqpo01mLJLSYDbxmfRgNMEw38Wg="' }
  let(:current_user) { TentD::Model::User.current }
  let(:other_user) { TentD::Model::User.create }

  it 'should parse hmac authorization header' do
    follow = Fabricate(:follower, :mac_key_id => "s:h480djs93hd8")
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
    follow = Fabricate(:follower, :mac_key_id => "s:h480djs93hd8")
    expect(follow.id).to_not be_nil
    env['HTTP_AUTHORIZATION'] = auth_header % 's'
    described_class.new(app).call(env)
    expect(env.potential_auth).to eq(follow.reload)
    expect(env.hmac.secret).to eq(follow.mac_key)
    expect(env.hmac.algorithm).to eq(follow.mac_algorithm)
  end

  it 'should not lookup server authentication model [follower] for another user' do
    follow = Fabricate(:follower, :mac_key_id => "s:h480djs93hd8", :user_id => other_user.id)
    env['HTTP_AUTHORIZATION'] = auth_header % 's'
    described_class.new(app).call(env)
    expect(env.potential_auth).to be_nil
  end

  it 'should not lookup server authentication model [following] for another user' do
    follow = Fabricate(:following, :mac_key_id => "s:h480djs93hd8", :user_id => other_user.id)
    env['HTTP_AUTHORIZATION'] = auth_header % 's'
    described_class.new(app).call(env)
    expect(env.potential_auth).to be_nil
  end

  it 'should lookup app authentication model' do
    authed_app = Fabricate(:app, :mac_key_id => "a:h480djs93hd8")
    expect(authed_app.id).to_not be_nil
    env['HTTP_AUTHORIZATION'] = auth_header % 'a'
    described_class.new(app).call(env)
    expect(env.potential_auth).to eq(authed_app)
    expect(env.hmac.secret).to eq(authed_app.mac_key)
    expect(env.hmac.algorithm).to eq(authed_app.mac_algorithm)
  end

  it 'should not lookup app authentication model for another user' do
    authed_app = Fabricate(:app, :mac_key_id => "a:h480djs93hd8", :user_id => other_user.id)
    env['HTTP_AUTHORIZATION'] = auth_header % 'a'
    described_class.new(app).call(env)
    expect(env.potential_auth).to be_nil
  end

  it 'should lookup user authentication model' do
    authed_user = TentD::Model::AppAuthorization.create(:mac_key_id => "u:h480djs93hd8",
                                                             :app => Fabricate(:app))
    expect(authed_user.id).to_not be_nil
    env['HTTP_AUTHORIZATION'] = auth_header % 'u'
    described_class.new(app).call(env)
    expect(env.potential_auth).to eq(authed_user)
    expect(env.hmac.secret).to eq(authed_user.mac_key)
    expect(env.hmac.algorithm).to eq(authed_user.mac_algorithm)
  end

  it 'should not lookup user authentication model for another user' do
    authed_user = TentD::Model::AppAuthorization.create(:mac_key_id => "u:h480djs93hd8",
                                                             :app => Fabricate(:app, :user_id => other_user.id))
    env['HTTP_AUTHORIZATION'] = auth_header % 'u'
    described_class.new(app).call(env)
    expect(env.potential_auth).to be_nil
  end

  it 'should do nothing unless HTTP_AUTHORIZATION header' do
    env = {}
    described_class.new(app).call(env)
    expect(env['hmac']).to be_nil
  end
end
