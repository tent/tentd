require 'json'

module TentD
  class API
    module Router
      class SerializeResponse
        def call(env)
          response = env.response.kind_of?(String) ? env.response : env.response.to_json if env.response
          status = env['response.status'] || (response ? 200 : 404)
          headers = { 'Content-Type' => env['response.type'] || MEDIA_TYPE }
          [status, headers, response.to_s]
        end
      end
    end
  end
end
