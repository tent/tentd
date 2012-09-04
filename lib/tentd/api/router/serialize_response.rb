require 'json'

module TentD
  class API
    module Router
      class SerializeResponse
        def call(env)
          response = if env.response
            env.response.kind_of?(String) ? env.response : env.response.to_json(serialization_options(env))
          end
          status = env['response.status'] || (response ? 200 : 404)
          headers = { 'Content-Type' => env['response.type'] || MEDIA_TYPE }
          [status, headers, [response.to_s]]
        end

        private

        def serialization_options(env)
          options = {}
          options[:kind] = :app if env.current_auth.respond_to?(:app)
          options[:permissions] = env.authorized_scopes.include?(:read_permissions)
          options
        end
      end
    end
  end
end
