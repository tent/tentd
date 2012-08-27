require 'json'

module TentServer
  class API
    module Router
      class SerializeResponse
        def call(env)
          status = env['response.status']
          status ||= env['response'].nil? ? 404 : 200
          [status, { 'Content-Type' => 'application/json' }, env['response'].to_json]
        end
      end
    end
  end
end
