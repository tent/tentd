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
      profile_infos = []
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"), :tent => true)
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"))
      profile_infos.each(&:save!)

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

  describe 'PATCH /profile' do
    it 'should update profile with given JSON diff array' do
      profile_infos = []
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"), :tent => true)
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"))
      profile_infos.each(&:save!)

      diff_array = [
        { "add" => "https:~1~1tent.io~1types~1info-types~1basic-info/city", "value" => "New York" },
        { "remove" => "https:~1~1tent.io/servers/1" }
      ]

      new_profile_hash = {
        "https://tent.io" => {
          "licenses" => ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"],
          "entity" => "https://smith.example.com",
          "servers" => ["https://smith.example.com"]
        },
        "https://tent.io/types/info-types/basic-info" => {
          "name" => "John Smith",
          "age" => 25,
          "city" => "New York"
        }
      }

      json_patch '/profile', diff_array, 'tent.entity' => 'smith.example.com'
      expect(last_response.body).to eq(new_profile_hash.to_json)
      expect(::TentServer::Model::ProfileInfo.build_for_entity('smith.example.com')).to eq(new_profile_hash)
    end

    it 'should not update profile if diff test fails' do
      profile_infos = []
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"), :tent => true)
      profile_infos << Fabricate(:profile_info, :entity => URI("https://smith.example.com"))
      profile_infos.each(&:save!)

      profile_hash = ::TentServer::Model::ProfileInfo.build_for_entity('smith.example.com')

      diff_array = [
        { "add" => "https:~1~1tent.io~1types~1info-types~1basic-info/city", "value" => "New York" },
        { "test" => "https:~1~1tent.io~1types~1info-types~1basic-info/age", "value" => 45 },
        { "remove" => "https:~1~1tent.io/servers/1" }
      ]

      json_patch '/profile', diff_array, 'tent.entity' => 'smith.example.com'
      expect(last_response.status).to eq(422)
      expect(last_response.body).to eq(profile_hash.to_json)
    end
  end
end
