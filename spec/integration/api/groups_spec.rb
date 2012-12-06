require 'spec_helper'

describe TentD::API::Groups do
  def app
    TentD::API.new
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
  let(:current_user) { TentD::Model::User.current }
  let(:other_user) { TentD::Model::User.create }

  describe 'GET /groups/count' do
    before { authorize!(:read_groups) }
    it 'should return number of groups' do
      Fabricate(:group)
      Fabricate(:group, :user_id => other_user.id)
      json_get '/groups/count', params, env
      expect(last_response.body).to eq(1.to_json)
    end
  end

  describe 'HEAD /groups' do
    before { authorize!(:read_groups) }
    it 'should return number of groups' do
      Fabricate(:group)
      Fabricate(:group)
      Fabricate(:group, :user_id => other_user.id)
      head '/groups', params, env
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Count']).to eql('2')
    end
  end

  describe 'GET /groups' do
    context 'when read_groups scope authorized' do
      before { authorize!(:read_groups) }

      it 'should return all groups' do
        Fabricate(:group, :name => 'chunky-bacon')
        Fabricate(:group, :name => 'chunky-other', :user_id => other_user.id)

        with_constants "TentD::API::PER_PAGE" => TentD::Model::Group.count + 1 do
          json_get '/groups', params, env
          expect(JSON.parse(last_response.body).size).to eq(TentD::Model::Group.where(:user_id => current_user.id).count)
        end
      end

      it 'should order by id desc' do
        first_group = Fabricate(:group)
        last_group = Fabricate(:group)

        json_get '/groups', params, env
        body = JSON.parse(last_response.body)
        body_ids = body.map { |i| i['id'] }
        expect(body_ids).to eq([last_group.public_id, first_group.public_id])
      end

      context 'with params' do
        it 'should filter by before_id' do
          group = Fabricate(:group)
          before_group = Fabricate(:group)

          params[:before_id] = before_group.public_id
          json_get '/groups', params, env
          expect(last_response.status).to eq(200)

          body = JSON.parse(last_response.body)
          body_ids = body.map { |i| i['id'] }
          expect(body_ids).to eq([group.public_id])
        end

        it 'should filter by since_id' do
          since_group = Fabricate(:group)
          group = Fabricate(:group)

          params[:since_id] = since_group.public_id
          json_get '/groups', params, env
          expect(last_response.status).to eq(200)

          body = JSON.parse(last_response.body)
          body_ids = body.map { |i| i['id'] }
          expect(body_ids).to eq([group.public_id])
        end

        it 'should support limit' do
          2.times { Fabricate(:group) }
          params[:limit] = 1

          json_get '/groups', params, env
          expect(last_response.status).to eq(200)

          body = JSON.parse(last_response.body)
          expect(body.size).to eq(1)
        end

        it 'should never return more than TentD::API::MAX_PER_PAGE groups' do
          Fabricate(:group)
          with_constants "TentD::API::MAX_PER_PAGE" => 0 do
            params[:limit] = 1
            json_get '/groups', params, env
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).size).to eq(0)
          end
        end

        it 'should set pagination in header' do
          group1 = Fabricate(:group)
          group2 = Fabricate(:group)

          with_constants "TentD::API::MAX_PER_PAGE" => 2 do
            json_get "/groups", params, env
            link_header = last_response.headers['Link'].to_s
            link_headers = link_header.split(', ')
            expect(link_headers).to include(%(<http://example.org/groups?before_id=#{group1.public_id}>; rel="next"))
            expect(link_headers).to include(%(<http://example.org/groups?since_id=#{group2.public_id}>; rel="prev"))

            head "/groups", params, env
            link_header = last_response.headers['Link'].to_s
            link_headers = link_header.split(', ')
            expect(link_headers).to include(%(<http://example.org/groups?before_id=#{group1.public_id}>; rel="next"))
            expect(link_headers).to include(%(<http://example.org/groups?since_id=#{group2.public_id}>; rel="prev"))
          end
        end
      end
    end

    context 'when read_groups scope unauthorized' do
      it 'should return 403' do
        get '/groups', params, env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end
    end
  end

  describe 'GET /groups/:id' do
    context 'when read_groups scope is authorized' do
      before { authorize!(:read_groups) }

      it 'should find group with :id' do
        group = Fabricate(:group)
        get "/groups/#{group.public_id}", params, env
        expect(JSON.parse(last_response.body)['id']).to eq(group.public_id)
      end

      it "should render 404 if :id doesn't exist" do
        get "/groups/invalid-id", params, env
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end

      context 'when group belongs to another user' do
        it 'should return 404' do
          group = Fabricate(:group, :user_id => other_user.id)
          get "/groups/#{group.public_id}", params, env
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end
      end
    end

    context 'when read_groups scope is unauthorized' do
      it 'should return 403' do
        get '/groups/group-id', params, env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
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
        actual_group = TentD::Model::Group.first(:id => group.id)
        expect(actual_group.name).to eq(group.name)
        expect(JSON.parse(last_response.body)['id']).to eq(actual_group.public_id)
      end

      it 'should return 404 unless group with :id exists' do
        json_put '/groups/invalid-id', params, env
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end

      context 'when group belongs to another user' do
        it 'should return 404' do
          group = Fabricate(:group, :user_id => other_user.id)
          json_put "/groups/#{group.public_id}", group, env
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end
      end
    end

    context 'when write_groups scope is not authorized' do
      it 'should return 403' do
        json_put '/groups/group-id', params, env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end
    end
  end

  describe 'POST /groups' do
    context 'when write_groups scope is authorized' do
      before { authorize!(:write_groups) }

      it 'should create group' do
        expect(lambda { json_post "/groups", { :name => 'bacon-bacon' }, env }).
          to change(TentD::Model::Group.where(:user_id => current_user.id), :count).by(1)
      end

      it 'should return existing group when public_id taken' do
        group = Fabricate(:group)
        expect(lambda {
          json_post "/groups", { :name => 'bacon-bacon', :public_id => group.public_id }, env
          expect(last_response.status).to eq(200)
          expect(Yajl::Parser.parse(last_response.body)['id']).to eq(group.public_id)
        }).to_not change(TentD::Model::Group.where(:user_id => current_user.id), :count)
      end

      it 'should create group with specified public_id' do
        TentD::Model::Group.destroy
        data = {
          :id => 'public-id',
          :name => 'bacon-bacon'
        }
        expect(lambda { json_post "/groups", data, env }).
          to change(TentD::Model::Group.where(:user_id => current_user.id), :count).by(1)

        group = TentD::Model::Group.order(:id.asc).last
        expect(group.name).to eq(data[:name])
        expect(group.public_id).to eq(data[:id])
      end
    end

    context 'when write_groups scope is not authorized' do
      it 'should return 403' do
        json_post '/groups', params, env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end
    end
  end

  describe 'DELETE /groups' do
    context 'when write_groups scope is authorized' do
      before { authorize!(:write_groups) }

      it 'should destroy group' do
        group = Fabricate(:group, :name => 'foo-bar-baz')
        expect(lambda { delete "/groups/#{group.public_id}", params, env }).
          to change(TentD::Model::Group, :count).by(-1)

        deleted_group = TentD::Model::Group.unfiltered.first(:id => group.id)
        expect(deleted_group).to_not be_nil
        expect(deleted_group.deleted_at).to_not be_nil
      end

      it 'should returh 404 if group does not exist' do
        Fabricate(:group, :name => 'baz')
        expect(lambda { delete "/groups/invalid-id", params, env }).
          to change(TentD::Model::Group, :count).by(0)
        expect(last_response.status).to eq(404)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
      end

      context 'when group belongs to another user' do
        let!(:group) { Fabricate(:group, :user_id => other_user.id) }

        it 'should return 404' do
          expect(lambda { delete "/groups/#{group.public_id}", params, env }).
            to change(TentD::Model::Group, :count).by(0)
          expect(last_response.status).to eq(404)
          expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Not Found' })
        end
      end
    end

    context 'when write_groups scope is not authorized' do
      it 'should return 403' do
        delete '/groups/group-id', params, env
        expect(last_response.status).to eq(403)
        expect(Yajl::Parser.parse(last_response.body)).to eql({ 'error' => 'Unauthorized' }) 
      end
    end
  end
end
