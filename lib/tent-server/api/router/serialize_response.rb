require 'json'

module TentServer
  class API
    module Router
      class SerializeResponse
        def call(env)
          response = env.response
          status = env['response.status'] || (response ? 200 : 404)
          headers = { 'Content-Type' => 'application/json' }
          [status, headers, response.to_json]
        end
      end
    end
  end
end
