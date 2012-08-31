require 'spec_helper'

describe TentServer::API::Apps do
  def app
    TentServer::API.new
  end

  describe 'GET /apps' do
    it 'should return list of apps' do
      Fabricate(:app)

      json_get '/apps'
      expect(last_response.body).to eq(
        TentServer::Model::App.all.map { |app| app.as_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta, :updated_at, :created_at]) }.to_json
      )
    end
  end

  describe 'GET /apps/:id' do
    context 'app with :id exists' do
      it 'should return app' do
        app = Fabricate(:app)

        json_get "/apps/#{app.id}"
        expect(last_response.body).to eq(
          app.to_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id])
        )
      end
    end

    context 'app with :id does not exist' do
      it 'should return 404' do
        json_get "/apps/#{(TentServer::Model::App.count + 1) * 100}"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'POST /apps' do
    it 'should create app' do
      data = Fabricate.build(:app).as_json(:only => [:name, :description, :url, :icon, :redirect_uris, :scopes])

      expect(lambda { json_post '/apps', data }).to change(TentServer::Model::App, :count).by(1)

      app = TentServer::Model::App.last
      expect(last_response.status).to eq(200)
      data.each_pair do |key, val|
        expect(app.send(key)).to eq(val)
      end
      expect(last_response.body).to eq(app.to_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id, :mac_key, :mac_algorithm]))
    end
  end

  describe 'PUT /apps/:id' do
    context 'app with :id exists' do
      it 'should update app' do
        app = Fabricate(:app)
        data = app.as_json(:only => [:name, :url, :icon, :redirect_uris, :scopes])
        data[:name] = "Yet Another MicroBlog App"
        data[:scopes] = {
          "read_posts" => "Can read your posts"
        }

        json_put "/apps/#{app.id}", data
        expect(last_response.status).to eq(200)
        app.reload
        data.each_pair do |key, val|
          expect(app.send(key)).to eq(val)
        end
        expect(last_response.body).to eq(app.to_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id]))
      end
    end

    context 'app with :id does not exist' do
      it 'should return 404' do
        json_put "/apps/#{(TentServer::Model::App.count + 1) * 100}"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe 'DELETE /apps/:id' do
    context 'app with :id exists' do
      it 'should delete app' do
        app = Fabricate(:app)

        expect(lambda { delete "/apps/#{app.id}" }).to change(TentServer::Model::App, :count).by(-1)
        expect(last_response.status).to eq(200)
      end
    end

    context 'app with :id does not exist' do
      it 'should return 404' do
        delete "/apps/#{(TentServer::Model::App.count + 1) * 100}"
        expect(last_response.status).to eq(404)
      end
    end
  end
end
