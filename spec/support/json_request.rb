require 'json'

module JsonRequest
  def json_put(path, data = {})
    put path, data.to_json, 'HTTP_CONTENT_TYPE' => 'application/json'
  end

  def json_post(path, data = {})
    post path, data.to_json, 'HTTP_CONTENT_TYPE' => 'application/json'
  end

  def json_get(path, data = {})
    get path, data, 'HTTP_ACCEPT' => 'application/json'
  end
end
