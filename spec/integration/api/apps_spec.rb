require 'spec_helper'

describe TentServer::API::Apps do
  def app
    TentServer::API.new
  end

  describe 'GET /apps' do
    it 'should return list of apps'
  end

  describe 'GET /apps/:id' do
    context 'app with :id exists' do
      it 'should return app'
    end

    context 'app with :id does not exist' do
      it 'should return 404'
    end
  end

  describe 'POST /apps' do
    it 'should create app' do
      data = {
        "name" => "MicroBlogger",
        "description" => "Manages your status posts",
        "url" => "https://microbloggerapp.example.com",
        "icon" => "https://microbloggerapp.example.com/icon.png",
        "redirect_uris" => ["https://microbloggerapp.example.com/auth/callback?foo=bar"],
        "scopes" => {
          "read_posts" => "Can read your posts",
          "create_posts" => "Can create posts on your behalf"
        }
      }

      expect(lambda { json_post '/apps', data }).to change(TentServer::Model::App, :count).by(1)

      app = TentServer::Model::App.last
      expect(last_response.body).to eq(app.to_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id, :mac_key, :mac_algorithm]))
    end
  end

  describe 'PATCH /apps/:id' do
    context 'app with :id exists' do
      it 'should update app with diff array'
    end

    context 'app with :id does not exist' do
      it 'should return 404'
    end
  end

  describe 'PUT /apps/:id' do
    context 'app with :id exists' do
      it 'should update app'
    end

    context 'app with :id does not exist' do
      it 'should return 404'
    end
  end

  describe 'DELETE /apps/:id' do
    context 'app with :id exists' do
      it 'should delete app'
    end

    context 'app with :id does not exist' do
      it 'should return 404'
    end
  end
end
