require 'spec_helper'
require 'hashie'

describe TentD::API::Authorization do
  def app
    TentD::API.new
  end

  let(:env) { Hashie::Mash.new }

  not_authorized = proc do
    it 'should not authorize scopes' do
      described_class.new(app).call(env)
      expect(env.authorized_scopes).to eq([])
    end
  end

  context 'without current_auth', &not_authorized

  context 'with current_auth' do
    context 'when Follower' do
      before do
        env.current_auth = Fabricate(:follower)
      end

      context '', &not_authorized
    end

    context 'when AppAuthorization' do
      before do
        env.current_auth = Fabricate(
          :app_authorization,
          :scopes => ['read_posts', 'write_posts'],
          :app => Fabricate(:app)
        )
      end

      it 'should lookup authorized scopes' do
        described_class.new(app).call(env)
        expect(env.authorized_scopes).to eq([:read_posts, :write_posts])
      end
    end
  end
end
