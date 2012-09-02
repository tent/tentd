require 'json'

module JsonRequest
  def json_patch(path, data = {}, rack_env = {})
    patch path, data.to_json,  { 'CONTENT_TYPE' => TentServer::API::MEDIA_TYPE }.merge(rack_env)
  end

  def json_put(path, data = {}, rack_env= {})
    put path, data.to_json, { 'CONTENT_TYPE' => TentServer::API::MEDIA_TYPE }.merge(rack_env)
  end

  def json_post(path, data = {}, rack_env = {})
    post path, data.to_json,  { 'CONTENT_TYPE' => TentServer::API::MEDIA_TYPE }.merge(rack_env)
  end

  def json_get(path, data = {}, rack_env = {})
    get path, data, { 'HTTP_ACCEPT' => TentServer::API::MEDIA_TYPE }.merge(rack_env)
  end
end
