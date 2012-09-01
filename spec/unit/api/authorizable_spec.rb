require 'spec_helper'
require 'hashie'

describe TentServer::API::Authorizable do
  class TestMiddleware2
    include TentServer::API::Authorizable

    def initialize(app)
      @app = app
    end

    def call(env)
      authorize_env!(env, :read_posts)
      @app.call(env)
    end
  end

  class OtherTestMiddleware < TentServer::API::Middleware
    def action(env)
      authorize_env!(env, :read_posts)
      env
    end
  end

  def app
    TentServer::API.new
  end

  let(:env) { Hashie::Mash.new }
  let(:middleware) { TestMiddleware2.new(app) }

  describe '#authorize_env!(env, scope)' do
    it 'should raise Unauthorized unless env.authorized_scopes includes scope' do
      expect( lambda { middleware.call(env) } ).to raise_error(described_class::Unauthorized)
    end

    it 'should do nothing if env.authorized_scopes includes scope' do
      env.authorized_scopes = [:read_posts]
      expect( lambda { middleware.call(env) } ).to_not raise_error
    end

    context 'when TentServer::API::Middleware' do
      it 'should respond 403 unless env.authorized_scopes includes scope' do
        response = OtherTestMiddleware.new(app).call(env)
        expect(response).to be_an(Array)
        expect(response.first).to be(403)
      end
    end
  end
end
