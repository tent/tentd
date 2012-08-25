require 'spec_helper'

describe TentServer::API::Router do
  class TestMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      env['response'] = { 'params' => env['params'] }
      @app.call(env)
    end
  end

  class TestMountedApp
    include TentServer::API::Router

    get '/chunky/:bacon' do |b|
      b.use TestMiddleware
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

    mount TestMountedApp
  end

  def app
    TestApp.new
  end

  it "should extract params" do
    get '/foo/baz'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['params']['bar']).to eq('baz')
  end

  it "should merge both sets of params" do
    post '/foo/baz/bar?chunky=bacon'
    expect(last_response.status).to eq(200)
    actual_body = JSON.parse(last_response.body)
    expect(actual_body['params']['chunky']).to eq('bacon')
    expect(actual_body['params']['captures']).to include('baz')
  end

  it "should work with mount" do
    get '/chunky/crunch'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['params']['bacon']).to eq('crunch')
  end
end
