require 'spec_helper'

describe TentServer::API::Groups do
  def app
    TentServer::API.new
  end

  def authorize!(*scopes)
    env['current_auth'] = stub(
      :kind_of? => true,
      :id => nil,
      :scopes => scopes
    )
  end

  let(:env) { Hash.new }
  let(:params) { Hash.new }

  describe 'GET /groups' do
    context 'when read_groups scope authorized' do
      before { authorize!(:read_groups) }

      it 'should return all groups' do
        Fabricate(:group, :name => 'chunky-bacon').save!

        get '/groups', params, env
        expect(last_response.body).to eq(TentServer::Model::Group.all.to_json)
      end
    end

    context 'when read_groups scope unauthorized' do
      it 'should return 403' do
        get '/groups', params, env
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'GET /groups/:id' do
    context 'when read_groups scope is authorized' do
      before { authorize!(:read_groups) }

      it 'should find group with :id' do
        group = Fabricate(:group)
        get "/groups/#{group.public_id}", params, env
        expect(last_response.body).to eq(group.to_json)
      end

      it "should render 404 if :id doesn't exist" do
        get "/groups/invalid-id", params, env
        expect(last_response.status).to eq(404)
      end
    end

    context 'when read_groups scope is unauthorized' do
      it 'should return 403' do
        get '/groups/group-id', params, env
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'PUT /groups/:id' do
    context 'when write_groups scope is authorized' do
      before { authorize!(:write_groups) }

      it 'should update group with :id' do
        group = Fabricate(:group, :name => 'foo-bar')
        group.name = 'bar-baz'
        expect(group.save).to be_true
        json_put "/groups/#{group.public_id}", group, env
        actual_group = TentServer::Model::Group.get(group.id)
        expect(actual_group.name).to eq(group.name)
        expect(last_response.body).to eq(actual_group.to_json)
      end

      it 'should return 404 unless group with :id exists' do
        json_put '/groups/invalid-id', params, env
        expect(last_response.status).to eq(404)
      end
    end

    context 'when write_groups scope is not authorized' do
      it 'should return 403' do
        json_put '/groups/group-id', params, env
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'POST /groups' do
    context 'when write_groups scope is authorized' do
      before { authorize!(:write_groups) }

      it 'should create group' do
        expect(lambda { json_post "/groups", { :name => 'bacon-bacon' }, env }).
          to change(TentServer::Model::Group, :count).by(1)
      end
    end

    context 'when write_groups scope is not authorized' do
      it 'should return 403' do
        json_post '/groups', params, env
        expect(last_response.status).to eq(403)
      end
    end
  end

  describe 'DELETE /groups' do
    context 'when write_groups scope is authorized' do
      before { authorize!(:write_groups) }

      it 'should destroy group' do
        group = Fabricate(:group, :name => 'foo-bar-baz')
        expect(lambda { delete "/groups/#{group.public_id}", params, env }).
          to change(TentServer::Model::Group, :count).by(-1)
      end

      it 'should returh 404 if group does not exist' do
        Fabricate(:group, :name => 'baz')
        expect(lambda { delete "/groups/invalid-id", params, env }).
          to change(TentServer::Model::Group, :count).by(0)
        expect(last_response.status).to eq(404)
      end
    end

    context 'when write_groups scope is not authorized' do
      it 'should return 403' do
        delete '/groups/group-id', params, env
        expect(last_response.status).to eq(403)
      end
    end
  end
end
