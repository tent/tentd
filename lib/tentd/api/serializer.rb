module TentD
  class API
    module Serializer
      def self.serialize(object, env)
        if object.kind_of?(Array)
          r = object.map { |i| i.as_json(self.serialization_options(env)) }
          r.to_json
        else
          object.to_json(self.serialization_options(env))
        end
      end

      def self.serialization_options(env)
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