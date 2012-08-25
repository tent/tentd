module TentServer
  class API
    module Router
      class SerializeResponse
        def call(env)
          [200, { 'Content-Type' => 'application/json' }, env['response'].to_json]
        end
      end
    end
  end
end
