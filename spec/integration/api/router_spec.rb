require 'spec_helper'

class TestMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    env['response'] = { 'params' => env['params'] }
    @app.call(env)
  end
end

class TestApp
  include TentServer::API::Router

  get '/foo/:bar' do |b|
    b.use TestMiddleware
  end
end

describe TentServer::API::Router do
  def app
    TestApp.new
  end

  it "should work" do
    get '/foo/baz'
    expect(JSON.parse(last_response.body)['params']['bar']).to eq('baz')
  end
end
