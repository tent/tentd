require 'spec_helper'

describe TentServer::API::Router do
  class TestMiddleware < TentServer::API::Middleware
    def action(env, params, request)
      env['response'] = { 'params' => env['params'] }
      env
    end
  end

  class TestMiddlewarePrematureResponse < TentServer::API::Middleware
    def action(env, params, request)
      [200, { 'Content-Type' => 'text/plain' }, 'Premature-Response']
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

    get '/premature/response' do |b|
      b.use TestMiddlewarePrematureResponse
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

  it "should allow middleware to prematurely respond" do
    get '/premature/response'
    expect(last_response.body).to eq('Premature-Response')
  end
end
