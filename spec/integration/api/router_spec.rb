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

  post %r{^/foo/([^/]+)/bar} do |b|
    b.use TestMiddleware
  end
end

describe TentServer::API::Router do
  def app
    TestApp.new
  end

  it "should extract params" do
    get '/foo/baz'
    expect(JSON.parse(last_response.body)['params']['bar']).to eq('baz')
  end

  it "should merge both sets of params" do
    post '/foo/baz/bar?chunky=bacon'
    expect(last_response.status).to eq(200)
    actual_body = JSON.parse(last_response.body)
    expect(actual_body['params']['chunky']).to eq('bacon')
    expect(actual_body['params']['captures']).to include('baz')
  end
end
