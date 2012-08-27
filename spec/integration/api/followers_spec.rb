require 'spec_helper'

describe TentServer::API::Followers do
  def app
    TentServer::API.new
  end

  def link_header(entity_url)
    %Q(<#{entity_url}/tent/profile>; rel="profile"; type="%s") % TentClient::PROFILE_MEDIA_TYPE
  end

  def tent_profile(entity_url)
    %Q({"https://tent.io/types/info/core/v0.1.0":{"licenses":["http://creativecommons.org/licenses/by/3.0/"],"entity":"#{entity_url}","servers":["#{entity_url}/tent"]}})
  end

  let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }

  describe 'POST /followers' do
    let(:follower_entity_url) { "https://alex.example.org" }
    let(:follower_data) do
      {
        "entity" => follower_entity_url,
        "licenses" => ["http://creativecommons.org/licenses/by-nc-sa/3.0/"],
        "types" => ["https://tent.io/types/posts/status/v0.1.x#full", "https://tent.io/types/posts/photo/v0.1.x#meta"]
      }
    end

    it 'should perform discovery' do
      http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
      http_stubs.get('/tent/profile') {
        [200, { 'Content-Type' => TentClient::PROFILE_MEDIA_TYPE }, tent_profile(follower_entity_url)]
      }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com'
      http_stubs.verify_stubbed_calls
    end

    it 'should error if discovery fails' do
      http_stubs.head('/') { [404, {}, 'Not Found'] }
      http_stubs.get('/') { [404, {}, 'Not Found'] }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com'
      expect(last_response.status).to eq(404)
    end

    it 'should fail if entity identifiers do not match' do
      http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
      http_stubs.get('/tent/profile') {
        [200, { 'Content-Type' => TentClient::PROFILE_MEDIA_TYPE }, tent_profile('https://otherentity.example.com')]
      }
      TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])

      json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com'
      expect(last_response.status).to eq(409)
    end

    context 'when discovery success' do
      before do
        http_stubs.head('/') { [200, { 'Link' => link_header(follower_entity_url) }, ''] }
        http_stubs.get('/tent/profile') {
          [200, { 'Content-Type' => TentClient::PROFILE_MEDIA_TYPE }, tent_profile(follower_entity_url)]
        }
        TentClient.any_instance.stubs(:faraday_adapter).returns([:test, http_stubs])
      end

      it 'should create follower db record' do
        expect(lambda { json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com' }).
          to change(TentServer::Model::Follow, :count).by(1)
        expect(last_response.status).to eq(200)
      end

      it 'should create notification subscription for each type given' do
        expect(lambda { json_post '/followers', follower_data, 'tent.entity' => 'smith.example.com' }).
          to change(TentServer::Model::NotificationSubscription, :count).by(2)
        expect(last_response.status).to eq(200)
        expect(TentServer::Model::NotificationSubscription.last.view).to eq('meta')
      end
    end
  end
end
