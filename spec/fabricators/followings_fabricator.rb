Fabricator(:following, :class_name => "TentServer::Model::Following") do
  entity "https://smith.example.com"
  licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  groups { ["family", "friends"].map {|name| g = Fabricate(:group); g.name = name; g.save!; g.public_id } }
  mac_key_id { SecureRandom.hex(4) }
  mac_key { SecureRandom.hex(16) }
  mac_algorithm 'hmac-sha-256'
  mac_timestamp_delta Time.now.to_i
  profile { |f|
    { 'https://tent.io/types/info/core/v0.1.0' =>
      { :entity => f[:entity], :licenses => f[:licenses], :servers => ["https://example.com"] }
    }.to_json
  }
end
