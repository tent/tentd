require 'json'

module JsonPostHelper
  def json_post(path, data = {})
    post path, data.to_json, 'CONTENT_TYPE' => 'application/json'
  end
end
