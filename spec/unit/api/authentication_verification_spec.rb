require 'spec_helper'

describe TentServer::API::AuthenticationVerification do
  def app
    TentServer::API.new
  end

  it 'should verify mac signature' do
    env = {
      'hmac' => {
        "id" => "s:h480djs93hd8", "ts" => "1336363200", "nonce" => "dj83hs9s", "mac" => "hqpo01mLJLSYDbxmfRgNMEw38Wg="
      },
      'hmac.key' => '489dks293j39',
      'hmac.algorithm' => 'hmac-sha-1',
      'rack.input' => StringIO.new("asdf\nasdf"),
      'REQUEST_METHOD' => 'POST',
      'SCRIPT_NAME' => "/resource/1",
      'QUERY_STRING' => "b=1&a=2",
      'HTTP_HOST' => "example.com",
      'SERVER_PORT' => "80"
    }
    described_class.new(app).call(env)
    expect(env['hmac.verified']).to be_true
  end

  it 'should respond 403 Unauthorized if signature fails verification' do
    env = {
      'hmac' => {
        "id" => "s:h480djs93hd8", "ts" => "1336363200", "nonce" => "dj83hs9s", "mac" => "hqpo01mLJLSYDbxmfRgNMEw38Wg="
      },
      'hmac.key' => 'WRONG-KEY',
      'hmac.algorithm' => 'hmac-sha-1',
      'rack.input' => StringIO.new("asdf\nasdf"),
      'REQUEST_METHOD' => 'POST',
      'SCRIPT_NAME' => "/resource/1",
      'QUERY_STRING' => "b=1&a=2",
      'HTTP_HOST' => "example.com",
      'SERVER_PORT' => "80"
    }
    env = described_class.new(app).call(env)
    expect(env).to be_an(Array)
    expect(env.first).to eq(403)
  end

  it 'should not do anything if no signature' do
    env = {}
    res = described_class.new(app).call(env)
    expect(env['hmac.verified']).to be_nil
  end
end
