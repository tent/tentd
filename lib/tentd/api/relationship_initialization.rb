require 'faraday'
require 'yajl'
require 'hawk'

module TentD
  class API

    module RelationshipInitialization
      extend self

      ENV_KEYS = {
        :credentials_url => 'tent.relationship.credentials-url'.freeze,
        :credentials_post => 'tent.relationship.credentials-post'.freeze,
        :meta => 'tent.relationship.meta'.freeze,
        :server => 'tent.relationship.server'.freeze,
      }.freeze

      def call(env)
        parse_credentials_link(env)
        perform_discovery(env)
        select_server(env)
        fetch_credentials(env)
        create_relationship(env)

        # cleanup
        ENV_KEYS.each { |k| env.delete(k) }

        env['response.status'] = 204

        env
      end

      private

      def halt!(status, message)
        raise Middleware::Halt.new(status, message)
      end

      def parse_credentials_link(env)
        unless link = env['request.links'].find { |link| link[:rel] == 'https://tent.io/rels/credentials' }
          halt!(400, "Expected link to credentials post!")
        end

        env[ENV_KEYS[:credentials_url]] = link[:url]
      end

      def perform_discovery(env)
        entity = env['data']['entity']
        unless meta = TentClient.new(entity).server_meta
          halt!(400, "Discovery of entity #{entity.inspect} failed!")
        end

        unless meta['entity'] == entity
          halt!(400, "Entity mismatch!")
        end

        env[ENV_KEYS[:meta]] = meta
      end

      def select_server(env)
        url_params = {
          :entity => env['data']['entity'],
        }
        credentials_url = env[ENV_KEYS[:credentials_url]]

        ##
        # Find server with post url that matches the credentials url
        server = env[ENV_KEYS[:meta]]['content']['servers'].find { |server|
          # Evaluate known params (i.e. entity)
          post_url = server['urls']['post'].gsub(/({([^}]+)})/) {
            if url_params.has_key?($2.to_sym)
              URI.encode_www_form_component(url_params[$2.to_sym])
            else
              $1
            end
          }

          # Take everything before and after post id
          start, _end = post_url.split('{post}')

          # Determine post id by removing everything before and after it
          id = credentials_url.
            sub(Regexp.new("\\A" + Regexp.escape(start.to_s)), "").
            sub(Regexp.new(Regexp.escape(_end.to_s) + "(/?[?&].*)?\\Z"), "")

          # Build current server's post url with guessed id
          expected_url = post_url.sub(/{post}/) { id }

          # Select the server if it's URI template matches the credentials url
          credentials_url.start_with?(expected_url)
        }

        unless server
          halt!(400, "Credentials link mismatch!")
        end

        env[ENV_KEYS[:server]] = server
      end

      def fetch_credentials(env)
        res = Faraday.get(env[ENV_KEYS[:credentials_url]]) do |request|
          request.headers['Accept'] = POST_CONTENT_TYPE % 'https://tent.io/types/credentials/v0#'
        end
        post = Yajl::Parser.parse(res.body)

        unless SchemaValidator.validate(post['type'], post)
          halt!(400, "Invalid credentials post!")
        end

        env[ENV_KEYS[:credentials_post]] = post
      rescue Faraday::Error::TimeoutError, Faraday::Error::ConnectionFailed
        halt!(400, "Failed to fetch linked credentials post: #{res.status}")
      rescue Yajl::ParseError
        halt!(400, "Invalid credentials post!")
      end

      def create_relationship(env)
        relationship_post, credentials_post = Model::Relationship.create_from_env(env)
        current_user = env['current_user']
        (env['response.links'] ||= []) << {
          :url => TentD::Utils.sign_url(
            env['current_user'].server_credentials,
            TentD::Utils.expand_uri_template(
              current_user.preferred_server['urls']['post'],
              :entity => current_user.entity,
              :post => credentials_post.public_id
            )
          ),
          :rel => "https://tent.io/rels/credentials"
        }
      end
    end

  end
end
