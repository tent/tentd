require 'hawk'

module TentD
  class API

    class Authentication < Middleware

      def action(env)
        return env unless auth_header = env['HTTP_AUTHORIZATION']

        res = Hawk::Server.authenticate(
          auth_header,
          :credentials_lookup => proc { |id| lookup_credentials(env, id) },
          :nonce_lookup => proc { |nonce| lookup_nonce(env, nonce) },
          :content_type => simple_content_type(env),
          :payload => rack_input(env),
          :host => env['SERVER_NAME'],
          :path => env['SCRIPT_NAME'] + env['PATH_INFO'],
          :port => env['SERVER_PORT'],
          :method => env['REQUEST_METHOD']
        )

        if Hawk::AuthorizationHeader::AuthenticationFailure === res
          halt!(403, "Authentication failure: #{res.message}")
        else
          env
        end
      end

      private

      def lookup_credentials(env, id)
        if credentials_post = Model::Credentials.lookup(env['current_user'], id)
          credentials = Model::Credentials.slice_credentials(credentials_post)
          {
            :id => credentials[:id],
            :key => credentials[:hawk_key],
            :algorithm => credentials[:hawk_algorithm]
          }
        end
      end

      def lookup_nonce(env, nonce)
      end

      def simple_content_type(env)
        env['CONTENT_TYPE'].to_s.split(';').first
      end

    end

  end
end
