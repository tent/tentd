Fabricator(:profile_info, :class_name => 'TentD::Model::ProfileInfo') do |f|
  f.public true
  f.type_base 'https://tent.io/types/info/core'
  f.type_version '0.1.0'
  f.content { |attrs|
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
  }
end

Fabricator(:basic_profile_info, :class_name => 'TentD::Model::ProfileInfo') do |f|
  f.public true
  f.type_base 'https://tent.io/types/info/basic'
  f.type_version '0.1.0'
  f.content {
    {
      "name" => "John Smith",
      "age" => 25
    }
  }
end
