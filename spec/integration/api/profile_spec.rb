require 'spec_helper'

describe TentD::API::Profile do
  def app
    TentD::API.new
  end

  let(:env) { {} }
  let(:params) { Hash.new }
  let(:current_user) { TentD::Model::User.current }
  let(:other_user) { TentD::Model::User.create }

  let(:authorized_info_types) { [] }
  let(:authorized_scopes) { [] }
  let(:app_authorization) do
    Fabricate(
      :app_authorization,
      :app => Fabricate(:app),
      :profile_info_types => authorized_info_types,
      :scopes => authorized_scopes
    )
  end

  let(:basic_info_type) { "https://tent.io/types/info/basic/v0.1.0" }
  let(:basic_info_content) do
    {
      "name" => "John Smith",
      "age" => 21
    }
  end

  let(:work_history_type) { "https://tent.io/types/info/work-history/v0.1.0" }
  let(:work_history_content) do
    {
      "employers" => ["Foo Corp"]
    }
  end

  def url_encode_type(type)
    URI.encode(type, ":/")
  end

  def create_info(type, content, options = {})
    attrs = {
      :public => options[:public], :type => type, :content => content
    }
    attrs[:user_id] = options[:user_id] if options[:user_id]
    Fabricate(:profile_info, attrs)
  end

  describe 'GET /profile' do
    context 'when read_profile scope authorized' do
      let(:authorized_scopes) { [:read_profile] }
      before { env['current_auth'] = app_authorization }

      context 'when authorized for all info types' do
        let(:authorized_info_types) { ['all'] }

        it 'should return all info types' do
          profile_infos = []
          profile_infos << Fabricate(:profile_info, :public => false)
          profile_infos << Fabricate(:basic_profile_info, :public => false)
          profile_infos << Fabricate(:basic_profile_info, :public => false, :user_id => other_user.id)

          json_get '/profile', params, env
          expect(Yajl::Parser.parse(last_response.body)).to eql(Hashie::Mash.new(
            "#{ profile_infos.first.type.uri }" => profile_infos.first.content.merge(:permissions => profile_infos.first.permissions_json),
            "#{ profile_infos.last.type.uri }" => profile_infos.last.content.merge(:permissions => profile_infos.first.permissions_json)
          ).to_hash)
        end

        it 'should not return profile info for another user' do
          profile_infos = []
          profile_infos << Fabricate(:profile_info, :public => false, :user_id => other_user.id)
          json_get '/profile', params, env
          body = Yajl::Parser.parse(last_response.body)
          expect(body).to eql({})
        end
      end

      context 'when authorized for specific info types' do
        let(:authorized_info_types) { ['https://tent.io/types/info/basic'] }

        it 'should only return authorized info types' do
          profile_infos = []
          profile_infos << Fabricate(:profile_info, :public => false, :type => "https://tent.io/types/info/basic/v0.1.0")
          profile_infos << Fabricate(:profile_info, :public => false)

          json_get '/profile', params, env
          expect(Yajl::Parser.parse(last_response.body)).to eql({
            "#{ profile_infos.first.type.uri }" => profile_infos.first.content.merge('permissions' => profile_infos.first.permissions_json.inject({}) { |m, (k,v)| m[k.to_s] = v; m })
          })
        end

        it 'should not return profile info for another user' do
          profile_infos = []
          profile_infos << Fabricate(:profile_info, :public => false, :type => "https://tent.io/types/info/basic/v0.1.0", :user_id => other_user.id)
          json_get '/profile', params, env
          body = Yajl::Parser.parse(last_response.body)
          expect(body).to eql({})
        end
      end
    end

    context 'when read_profile scope unauthorized' do
      it 'should only return public profile into types' do
        profile_infos = []
        profile_infos << Fabricate(:profile_info, :public => true)
        profile_infos << Fabricate(:basic_profile_info, :public => false)

        json_get '/profile', params, env
        expect(last_response.body).to eql({
          "#{ profile_infos.first.type.uri }" => profile_infos.first.content.merge(:permissions => profile_infos.first.permissions_json)
        }.to_json)
      end

      it 'should not return profile info for another user' do
        profile_infos = []
        profile_infos << Fabricate(:profile_info, :public => true, :user_id => other_user.id)
        json_get '/profile', params, env
        body = Yajl::Parser.parse(last_response.body)
        expect(body).to eql({})
      end
    end
  end

  describe 'PUT /profile/:type_url' do
    before { env['current_auth'] = app_authorization }

    context 'when authorized' do
      let(:authorized_scopes) { [:write_profile] }

      can_update_basic_info_type = proc do
        it 'should update info type' do
          info = create_info(basic_info_type, basic_info_content, :public => false)

          expect(info.type.uri).to eql(basic_info_type)

          data = {
            "name" => "John Doe"
          }

          json_put "/profile/#{url_encode_type(basic_info_type)}", data, env

          expect(last_response.status).to eql(200)
          expect(info.reload.content).to eql(data)

          expect(info.reload.type.uri).to eql(basic_info_type)

        end

        it 'should create unless exists' do
          data = {
            "name" => "John Doe"
          }

          expect(lambda {
            json_put "/profile/#{url_encode_type(basic_info_type)}", data, env
          }).to change(TentD::Model::ProfileInfo.where(:user_id => current_user.id), :count).by(1)

          info = TentD::Model::ProfileInfo.order(:id.asc).last
          expect(last_response.status).to eql(200)
          expect(info.content).to eql(data)
          expect(info.type.version).to eql('0.1.0')
        end

        it 'should not update info for another user' do
          info = create_info(basic_info_type, basic_info_content, :public => false, :user_id => other_user.id)

          data = {
            "name" => "John Doe"
          }

          expect(lambda {
            json_put "/profile/#{url_encode_type(basic_info_type)}", data, env
          }).to change(TentD::Model::ProfileInfo.where(:user_id => current_user.id), :count).by(1)
        end
      end

      context 'when all info types authorized' do
        let(:authorized_info_types) { ['all'] }

        context '', &can_update_basic_info_type
      end

      context 'when specific info types authorized' do
        context 'when :type_url authorized info type' do
          let(:authorized_info_types) { [basic_info_type] }

          context '', &can_update_basic_info_type
        end

        context 'when :type_url not authoried info type' do
          it 'should return 403' do
            json_put "/profile/#{url_encode_type(basic_info_type)}", params, env
            expect(last_response.status).to eql(403)
          end
        end
      end
    end

    context 'when not authorized' do
      it 'should return 403' do
        json_put "/profile/#{url_encode_type(basic_info_type)}", params, env
        expect(last_response.status).to eql(403)
      end
    end
  end
end
