Fabricator(:profile_info, :class_name => 'TentServer::Model::ProfileInfo') do
  transient :tent
  entity URI("https://johnsmith.example.org")
  type do |attrs|
    if attrs[:tent]
      URI("https://tent.io")
    else
      URI("https://tent.io/types/info-types/basic-info")
    end
  end
  content do |attrs|
    if attrs[:tent]
      {
        "licenses" => [
          "http://creativecommons.org/licenses/by-nc-sa/3.0/",
          "http://www.gnu.org/copyleft/gpl.html"
        ],
        "entity" => attrs[:entity],
        "servers" => [
          attrs[:entity],
          "https://backup-johnsmith.example.com"
        ]
      }
    else
      {
        "name" => "John Smith",
        "age" => 25
      }
    end
  end
end
