require 'json'

module JsonRequest
  def json_put(path, data = {}, rack_env= {})
    put path, data.to_json, { 'HTTP_CONTENT_TYPE' => 'application/json' }.merge(rack_env)
  end

  def json_post(path, data = {}, rack_env = {})
    post path, data.to_json,  { 'HTTP_CONTENT_TYPE' => 'application/json' }.merge(rack_env)
  end

  def json_get(path, data = {}, rack_env = {})
    get path, data, { 'HTTP_ACCEPT' => 'application/json' }.merge(rack_env)
  end
end
