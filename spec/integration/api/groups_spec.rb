require 'spec_helper'

describe TentServer::API::Groups do
  def app
    TentServer::API.new
  end

  describe 'GET /groups' do
    it 'should return all groups' do
      Fabricate(:group, :name => 'chunky-bacon').save!

      get '/groups'
      expect(last_response.body).to eq(TentServer::Model::Group.all.to_json)
    end
  end

  describe 'GET /groups/:id' do
    it 'should find group with :id' do
      group = Fabricate(:group)
      get "/groups/#{group.public_uid}"
      expect(last_response.body).to eq(group.to_json)
    end

    it "should render 404 if :id doesn't exist" do
      get "/groups/invalid-id"
      expect(last_response.status).to eq(404)
    end
  end

  describe 'PUT /groups/:id' do
    it 'should update group with :id' do
      group = Fabricate(:group, :name => 'foo-bar')
      group.name = 'bar-baz'
      expect(group.save).to be_true
      json_put "/groups/#{group.public_uid}", group
      actual_group = TentServer::Model::Group.get(group.id)
      expect(actual_group.name).to eq(group.name)
      expect(last_response.body).to eq(actual_group.to_json)
    end
  end

  describe 'POST /groups' do
    it 'should create group' do
      group = Fabricate.build(:group, :name => 'bacon-bacon')
      expect(lambda { json_post "/groups", group.as_json(:exclude => [:id, :public_uid, :updated_at, :created_at]) }).
        to change(TentServer::Model::Group, :count).by(1)
    end
  end

  describe 'DELETE /groups' do
    it 'should destroy group' do
      group = Fabricate(:group, :name => 'foo-bar-baz')
      expect(lambda { delete "/groups/#{group.public_uid}" }).
        to change(TentServer::Model::Group, :count).by(-1)
    end

    it 'should returh 404 if group does not exist' do
      Fabricate(:group, :name => 'baz')
      expect(lambda { delete "/groups/#{TentServer::Model::Group.count * 100}" }).
        to change(TentServer::Model::Group, :count).by(0)
      expect(last_response.status).to eq(404)
    end
  end
end
