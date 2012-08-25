require 'json'

module TentServer
  class API
    module Router
      class SerializeResponse
        def call(env)
          [env['response.status'] || 200, { 'Content-Type' => 'application/json' }, env['response'].to_json]
        end
      end
    end
  end
end
