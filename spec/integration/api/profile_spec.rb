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

      json_get "/profile", nil, 'tent.entity' => "smith.example.com"
      expect(last_response.body).to eq([
        {
          :type => profile_infos.first.type.to_s
        }.merge(profile_infos.first.content),
        {
          :type => profile_infos.last.type.to_s
        }.merge(profile_infos.last.content)
      ].to_json)
    end
  end
end
