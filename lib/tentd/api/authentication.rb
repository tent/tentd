require 'hawk'

module TentD
  class API

    class Authentication < Middleware

      def action(env)
        header_authentication!(env)
        bewit_authentication!(env)
        env
      end

      def header_authentication!(env)
        return unless auth_header = env['HTTP_AUTHORIZATION']

        res = Hawk::Server.authenticate(
          auth_header,
          :credentials_lookup => proc { |id| lookup_credentials(env, id) },
          :nonce_lookup => proc { |nonce| lookup_nonce(env, nonce) },
          :content_type => simple_content_type(env),
          :payload => rack_input(env),
          :host => request_host(env),
          :path => request_path(env),
          :port => request_port(env),
          :method => request_method(env)
        )

        if Hawk::AuthenticationFailure === res
          halt!(403, "Authentication failure: #{res.message}")
        else
          env['current_auth'] = res
        end
      end

      def bewit_authentication!(env)
        return unless bewit = env['params']['bewit']

        res = Hawk::Server.authenticate_bewit(
          bewit,
          :credentials_lookup => proc { |id| lookup_credentials(env, id) },
          :host => request_host(env),
          :path => request_path(env),
          :port => request_port(env),
          :method => request_method(env)
        )

        if Hawk::AuthenticationFailure === res
          halt!(403, "Authentication failure: #{res.message}")
        else
          env['current_auth'] = res
        end
      end

      private

      def lookup_credentials(env, id)
        return unless id =~ TentD::REGEX::VALID_ID

        return unless credentials = if id == env['current_user'].server_credentials['id']
          resource = env['current_user']
          TentD::Utils::Hash.symbolize_keys(env['current_user'].server_credentials)
        elsif credentials_post = Model::Credentials.lookup(env['current_user'], id)
          resource = credentials_post
          Model::Credentials.slice_credentials(credentials_post)
        end

        return unless credentials

        {
          :id => credentials[:id],
          :key => credentials[:hawk_key],
          :algorithm => credentials[:hawk_algorithm],
          :resource => resource
        }
      end

      def lookup_nonce(env, nonce)
      end

      def simple_content_type(env)
        env['CONTENT_TYPE'].to_s.split(';').first
      end

      def request_host(env)
        env['SERVER_NAME']
      end

      def request_path(env)
        env['PATH_INFO'] + (env['QUERY_STRING'] != "" ? "?#{env['QUERY_STRING']}" : "")
      end

      def request_port(env)
        env['SERVER_PORT']
      end

      def request_method(env)
        env['REQUEST_METHOD']
      end

    end

  end
end
