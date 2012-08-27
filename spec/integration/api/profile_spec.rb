require 'spec_helper'

describe TentServer::API::Profile do
  def app
    TentServer::API.new
  end

  describe 'GET /profile' do
    it 'should find profile of server' do
      TentServer::Model::ProfileInfo.all.destroy

      profile_infos = []
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"), :tent => true)
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"))
      profile_infos.each(&:save!)

      json_get '/profile', nil, 'tent.entity' => 'smith.example.com'
      expect(last_response.body).to eq({
        "#{ profile_infos.first.type }" => profile_infos.first.content,
        "#{ profile_infos.last.type }" => profile_infos.last.content
      }.to_json)
    end
  end

  describe 'PUT /profile' do
    it 'should replace profile with given JSON' do
      data = {
        "https://tent.io" => {
          "licenses" => ["http://creativecommons.org/licenses/by-nc-sa/3.0/"],
          "entity" => 'https://backup-johnsmith.example.com',
          "servers" => ['https://backup-johnsmith.example.com', 'https://smith.example.org']
        },
        "https://tent.io/types/info-types/basic-info" => {
          "name" => "Smith",
          "age" => 30
        }
      }

      json_put '/profile', data, 'tent.entity' => 'smith.example.com'
      profile_infos = TentServer::Model::ProfileInfo.all(:entity => URI('https://smith.example.com'))
      expect(profile_infos.count).to eq(2)
      expect(last_response.body).to eq({
        "#{profile_infos.first.type}" => profile_infos.first.content,
        "#{ profile_infos.last.type }" => profile_infos.last.content
      }.to_json)
    end
  end
end
