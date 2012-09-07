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
          headers = if env['response.type'] || status == 200 && response && !response.empty?
                      { 'Content-Type' => env['response.type'] || MEDIA_TYPE } 
                    else
                      {}
                    end
          headers.merge('Access-Control-Allow-Origin' => '*') if env['HTTP_ORIGIN']
          [status, headers, [response.to_s]]
        end

        private

        def serialization_options(env)
          {
            :app => env.current_auth.kind_of?(Model::AppAuthorization),
            :authorization_token => env.authorized_scopes.include?(:read_apps),
            :permissions => env.authorized_scopes.include?(:read_permissions),
            :groups => env.authorized_scopes.include?(:read_groups),
            :mac => env.authorized_scopes.include?(:read_secrets),
            :self => env.authorized_scopes.include?(:self),
            :auth_token => env.authorized_scopes.include?(:authorization_token)
          }
        end
      end
    end
  end
end
