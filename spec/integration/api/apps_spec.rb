require 'spec_helper'

describe TentServer::API::Apps do
  def app
    TentServer::API.new
  end

  def authorize!(*scopes)
    env['current_auth'] = stub(
      :kind_of? => true,
      :app_id => nil,
      :scopes => scopes
    )
  end

  let(:env) { Hash.new }

  describe 'GET /apps' do
    context 'when authorized' do
      before { authorize!(:read_apps) }

      it 'should return list of apps' do
        Fabricate(:app)

        json_get '/apps', nil, env
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(
          TentServer::Model::App.all.map { |app| app.as_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta, :updated_at, :created_at]) }.to_json
        )
      end
    end

    context 'when unauthorized' do
      it 'should respond 403' do
        json_get '/apps', nil, env
        expect(last_response.status).to eq(403)
      end

      context 'when pretending to be authorized' do
        let(:_app) { Fabricate(:app) }
        before do
          env['current_auth'] = Fabricate(:app_authorization, :app => _app)
        end

        it 'should respond 403' do
          json_get "/apps?app_id=#{ _app.id }", nil, env
          expect(last_response.status).to eq(403)
        end
      end
    end
  end

  describe 'GET /apps/:id' do
    authorized_examples = proc do
      context 'app with :id exists' do
        it 'should return app' do
          app = _app

          json_get "/apps/#{app.id}", nil, env
          expect(last_response.status).to eq(200)
          expect(last_response.body).to eq(
            app.to_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id])
          )
        end
      end
    end

    context 'when authorized via scope' do
      let(:_app) { Fabricate(:app) }
      before { authorize!(:read_apps) }

      context '', &authorized_examples

      context 'app with :id does not exist' do
        it 'should return 404' do
          json_get "/apps/app-id", nil, env
          expect(last_response.status).to eq(404)
        end
      end
    end

    context 'when authorized via identity' do
      let(:_app) { Fabricate(:app) }
      before do
        env['current_auth'] = Fabricate(:app_authorization, :app => _app)
      end

      context '', &authorized_examples

      context 'app with :id does not exist' do
        it 'should return 403' do
          json_get '/apps/app-id', nil, env
          expect(last_response.status).to eq(403)
        end
      end
    end

    context 'when unauthorized' do
      it 'should respond 403' do
        json_get "/apps/app-id", nil, env
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'POST /apps' do
    it 'should create app' do
      data = Fabricate.build(:app).as_json(:only => [:name, :description, :url, :icon, :redirect_uris, :scopes])

      TentServer::Model::App.all.destroy
      expect(lambda { json_post '/apps', data, env }).to change(TentServer::Model::App, :count).by(1)

      app = TentServer::Model::App.last
      expect(last_response.status).to eq(200)
      data.each_pair do |key, val|
        expect(app.send(key)).to eq(val)
      end
      expect(last_response.body).to eq(app.to_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id, :mac_key, :mac_algorithm]))
    end
  end

  describe 'PUT /apps/:id' do
    authorized_examples = proc do
      context 'app with :id exists' do
        it 'should update app' do
          app = _app
          data = app.as_json(:only => [:name, :url, :icon, :redirect_uris, :scopes])
          data[:name] = "Yet Another MicroBlog App"
          data[:scopes] = {
            "read_posts" => "Can read your posts"
          }

          json_put "/apps/#{app.id}", data, env
          expect(last_response.status).to eq(200)
          app.reload
          data.each_pair do |key, val|
            expect(app.send(key)).to eq(val)
          end
          expect(last_response.body).to eq(app.to_json(:only => [:id, :name, :description, :url, :icon, :redirect_uris, :scopes, :mac_key_id]))
        end
      end
    end

    context 'when authorized via scope' do
      let(:_app) { Fabricate(:app) }
      before { authorize!(:write_apps) }

      context '', &authorized_examples

      context 'app with :id does not exist' do
        it 'should return 404' do
          json_put "/apps/#{(TentServer::Model::App.count + 1) * 100}", nil, env
          expect(last_response.status).to eq(404)
        end
      end
    end

    context 'when authorized via identity' do
      let(:_app) { Fabricate(:app) }

      before do
        env['current_auth'] = Fabricate(:app_authorization, :app => _app)
      end

      context '', &authorized_examples

      context 'app with :id does not exist' do
        it 'should return 403' do
          json_put "/apps/app-id", nil, env
          expect(last_response.status).to eq(403)
        end
      end
    end

    context 'when unauthorized' do
      it 'should respond 403' do
        json_put '/apps/app-id', nil, env
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'DELETE /apps/:id' do
    authorized_examples = proc do
      context 'app with :id exists' do
        it 'should delete app' do
          app = _app
          expect(app).to be_saved

          expect(lambda {
            delete "/apps/#{app.id}", nil, env
            expect(last_response.status).to eq(200)
          }).to change(TentServer::Model::App, :count).by(-1)
        end
      end
    end

    context 'when authorized via scope' do
      before { authorize!(:write_apps) }
      let(:_app) { Fabricate(:app) }

      context '', &authorized_examples
      context 'app with :id does not exist' do
        it 'should return 404' do
          delete "/apps/app-id", nil, env
          expect(last_response.status).to eq(404)
        end
      end
    end

    context 'when authorized via identity' do
      let(:_app) { Fabricate(:app) }
      before do
        env['current_auth'] = Fabricate(:app_authorization, :app => _app )
      end

      context '', &authorized_examples

      context 'app with :id does not exist' do
        it 'should respond 403' do
          delete '/apps/app-id', nil, env
          expect(last_response.status).to eq(403)
        end
      end
    end

    context 'when unauthorized' do
      it 'should respond 403' do
        delete '/apps/app-id', nil, env
        expect(last_response.status).to eq(403)
      end
    end
  end
end
