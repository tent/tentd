require 'spec_helper'

describe TentD::API::Router do
  class TestMiddleware < TentD::API::Middleware
    def action(env)
      env['response'] = { 'params' => env['params'] }
      env
    end
  end

  class TestMiddlewarePrematureResponse < TentD::API::Middleware
    def action(env)
      [200, { 'Content-Type' => 'text/plain' }, 'Premature-Response']
    end
  end

  class TestMountedApp
    include TentD::API::Router

    get '/chunky/:bacon' do |b|
      b.use TestMiddleware
    end
  end

  class TestApp
    include TentD::API::Router

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

  let(:env) { { 'authorized_scopes' => [] } }

  it "should extract params" do
    json_get '/foo/baz', nil, env
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['params']['bar']).to eq('baz')
  end

  it "should merge both sets of params" do
    json_post '/foo/baz/bar?chunky=bacon', nil, env
    expect(last_response.status).to eq(200)
    actual_body = JSON.parse(last_response.body)
    expect(actual_body['params']['chunky']).to eq('bacon')
    expect(actual_body['params']['captures']).to include('baz')
  end

  it "should work with mount" do
    json_get '/chunky/crunch', nil, env
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)['params']['bacon']).to eq('crunch')
  end

  it "should allow middleware to prematurely respond" do
    json_get '/premature/response', nil, env
    expect(last_response.body).to eq('Premature-Response')
  end
end
