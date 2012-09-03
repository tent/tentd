require 'json'

module JsonRequest
  def json_patch(path, data = {}, rack_env = {})
    patch path, data.to_json,  { 'CONTENT_TYPE' => TentD::API::MEDIA_TYPE }.merge(rack_env)
  end

  def json_put(path, data = {}, rack_env= {})
    put path, data.to_json, { 'CONTENT_TYPE' => TentD::API::MEDIA_TYPE }.merge(rack_env)
  end

  def json_post(path, data = {}, rack_env = {})
    post path, data.to_json, { 'CONTENT_TYPE' => TentD::API::MEDIA_TYPE }.merge(rack_env)
  end

  def json_get(path, data = {}, rack_env = {})
    get path, data, { 'HTTP_ACCEPT' => TentD::API::MEDIA_TYPE }.merge(rack_env)
  end

  def multipart_post(path, json, parts, rack_env = {})
    body = build_json_part(json) + build_parts(parts) + "--#{Rack::Multipart::MULTIPART_BOUNDARY}--\r"
    post path, body, { 'CONTENT_TYPE' => "multipart/form-data; boundary=#{Rack::Multipart::MULTIPART_BOUNDARY}",
                       'HTTP_ACCEPT' =>  TentD::API::MEDIA_TYPE }.merge(rack_env)
  end

  private

  def build_json_part(json)
    build_part('post', :filename => 'post.json', :content_type => TentD::API::MEDIA_TYPE, :content => json.to_json)
  end

  def build_parts(parts)
    parts.map do |k,v|
      v.kind_of?(Array) ? v.map { |part| build_part(k, part) } : build_part(k, v)
    end.join
  end

  def build_part(name, data)
<<-EOF
--#{Rack::Multipart::MULTIPART_BOUNDARY}\r
Content-Disposition: form-data; name="#{name}"; filename="#{Rack::Utils.escape(data[:filename])}"\r
Content-Type: #{data[:content_type]}\r
Content-Length: #{data[:content].size}\r
\r
#{data[:content]}\r
EOF
  end
end
