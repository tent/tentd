require 'json'

module TentD
  class API
    module Router
      class SerializeResponse
        def call(env)
          response = if env.response
            env.response.kind_of?(String) ? env.response : serialize_response(env)
          end
          status = env['response.status'] || (response ? 200 : 404)
          headers = if env['response.type'] || status == 200 && response && !response.empty?
                      { 'Content-Type' => env['response.type'] || MEDIA_TYPE } 
                    else
                      {}
                    end.merge(env['response.headers'] || {})
          status, headers, response = serialize_error_response(status, headers, response) if (400...600).include?(status)
          [status, headers, [response.to_s]]
        end

        def serialize_response(env)
          object = env.response
          if object.kind_of?(Array)
            r = object.map { |i| i.as_json(serialization_options(env)) }
            r.to_json
          else
            object.to_json(serialization_options(env))
          end
        end

        private

        def serialize_error_response(status, headers, response)
          unless response
            status = 404
            response = 'Not Found'
          end

          [status, headers.merge('Content-Type' => MEDIA_TYPE), { :error => response }.to_json]
        end

        def serialization_options(env)
          {
            :app => env.current_auth.kind_of?(Model::AppAuthorization),
            :authorization_token => env.authorized_scopes.include?(:read_apps),
            :permissions => env.authorized_scopes.include?(:read_permissions),
            :groups => env.authorized_scopes.include?(:read_groups),
            :mac => env.authorized_scopes.include?(:read_secrets),
            :self => env.authorized_scopes.include?(:self),
            :auth_token => env.authorized_scopes.include?(:authorization_token),
            :view => env.params.view
          }
        end
      end
    end
  end
end
