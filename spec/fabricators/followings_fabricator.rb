Fabricator(:following, :class_name => "TentD::Model::Following") do
  transient :server_urls
  entity "https://smith.example.com"
  licenses ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"]
  groups { ["family", "friends"].map {|name| Fabricate(:group, :name => name).public_id } }
  types { ['all'] }
  mac_key_id { SecureRandom.hex(4) }
  mac_key { SecureRandom.hex(16) }
  mac_algorithm 'hmac-sha-256'
  mac_timestamp_delta Time.now.to_i
  profile { |f|
    { TentD::Model::ProfileInfo::TENT_PROFILE_TYPE_URI =>
      { :entity => f[:entity], :licenses => f[:licenses], :servers => Array(f[:server_urls] || ["https://example.com"]) }
    }
  }
  updated_at { Time.now }
  confirmed true
end
