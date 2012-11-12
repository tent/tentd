require 'spec_helper'

describe 'Authentication' do

  def app
    TentD::API.new
  end

  let(:env) do
    Hashie::Mash.new({
      'rack.input' => StringIO.new("asdf\nasdf"),
      'QUERY_STRING' => "b=1&a=2",
      'HTTP_HOST' => "example.com",
      'SERVER_PORT' => "80"
    })
  end

  let(:mac_key_id_hex) { "41b954f112a1" }
  let(:mac_key) { "c81c01908a35c460a07a98ab7167a2e8" }
  let(:auth_header) { %(MAC id="%s:#{mac_key_id_hex}", ts="1336363200", nonce="dj83hs9s", mac="iqYTKvVQGIwVYwrf0A9hEiKLdbQcwEvk802ZitOY+2w=") }
  let(:mac_algorithm) { 'hmac-sha-256' }

  context 'with valid hmac' do
    let(:mac_key_id) { "#{mac_key_id_prefix}:#{mac_key_id_hex}" }
    before { env['HTTP_AUTHORIZATION'] = auth_header % mac_key_id_prefix }

    expect_hmac_verified_examples = proc do
      it 'should verify hmac' do
        subject # create
        get '/posts', {}, env
        expect(last_response.status).to eq(200)
      end
    end

    context 'when server' do
      context 'when follower' do
        let(:mac_key_id_prefix) { "s" }
        let(:subject) {
          DataMapper.auto_migrate!
          TentD::Model::User.current = TentD::Model::User.first_or_create
          Fabricate(:follower, :mac_key_id => mac_key_id, :mac_algorithm => mac_algorithm, :mac_key => mac_key)
        }

        context &expect_hmac_verified_examples
      end

      context 'when following' do
        let(:mac_key_id_prefix) { "s" }
        let(:subject) {
          DataMapper.auto_migrate!
          TentD::Model::User.current = TentD::Model::User.first_or_create
          Fabricate(:following, :mac_key_id => mac_key_id, :mac_algorithm => mac_algorithm, :mac_key => mac_key)
        }

        context &expect_hmac_verified_examples
      end
    end

    context 'when app' do
      let(:mac_key_id_prefix) { "a" }
      let(:subject) {
        TentD::Model::App.all.destroy!
        Fabricate(:app, :mac_key_id => mac_key_id, :mac_algorithm => mac_algorithm, :mac_key => mac_key)
      }

      context &expect_hmac_verified_examples
    end
  end

  context 'with invalid hmac' do
    let(:mac_key_id_hex) { "1234" }
    let(:mac_key_id) { "#{mac_key_id_prefix}:#{mac_key_id_hex}" }
    let(:invalid_mac_key) { "invalid-mac-key" }
    before { env['HTTP_AUTHORIZATION'] = auth_header % mac_key_id_prefix }

    expect_hmac_invalid_examples = proc do
      it 'should verify hmac' do
        subject # create
        get '/posts', {}, env
        expect(last_response.status).to eq(401)
        expect(last_response.body).to match(/invalid/i)
      end
    end

    context 'when server' do
      context 'when follower' do
        let(:mac_key_id_prefix) { "s" }
        let(:subject) {
          Fabricate(:follower)
        }

        context &expect_hmac_invalid_examples
      end

      context 'when following' do
        let(:mac_key_id_prefix) { "s" }
        let(:subject) {
          Fabricate(:following)
        }

        context &expect_hmac_invalid_examples
      end
    end

    context 'when app' do
      let(:mac_key_id_prefix) { "a" }
      let(:subject) {
        Fabricate(:app)
      }

      context &expect_hmac_invalid_examples
    end
  end

  context 'without hmac header' do
    it 'should return public content' do
      get '/posts', {}, env
      expect(last_response.status).to eq(200)
    end
  end
end
