require 'faraday'
require 'yajl'
require 'hawk'

module TentD
  class API

    class RelationshipInitialization

      def self.call(env)
        new(env).perform
      end

      attr_reader :env, :current_user, :initiating_credentials_url, :initiating_credentials_post, :initiating_meta_post, :initiating_server, :initiating_entity_uri, :initiating_entity, :initiating_relationship_post
      def initialize(env)
        @env = env
        @current_user = env['current_user']
      end

      ##
      # Perform relationship initiation steps,
      # return 400 response if/when any of the steps fail
      def perform
        ##
        # Ensure relationship post is valid
        # (ValidateInputData middleware will have validated it against the schema already if in correct format)
        unless Hash === env['data']
          halt!(400, "Invalid relationship post!", :post => env['data'])
        end

        ##
        # relationship#initial post
        @initiating_relationship_post = Utils::Hash.symbolize_keys(env['data'])

        ##
        # Entity of server initiating relationship
        @initiating_entity_uri = env['data']['entity']
        @initiating_entity = Model::Entity.first_or_create(initiating_entity_uri)

        ##
        # Fetch meta post from initiating server via discovery
        @initiating_meta_post = perform_discovery

        ##
        # Ensure we have the correct meta post
        meta = initiating_meta_post
        unless (Hash === meta) && (Hash === meta['content']) && meta['content']['entity'] == initiating_entity_uri
          patch = { :op => "replace", :path => "/content/entity", :value => initiating_entity_uri }

          if !(Hash === meta) || !(Hash === meta['content']) || !meta['content'].has_key?('entity')
            patch[:op] = "add"
          end

          halt!(400, "Entity mismatch!", :diff => [patch], :post => meta)
        end

        ##
        # Parse signed credentials url for relationship post from Link header
        @initiating_credentials_url = parse_credentials_link

        ##
        # Find preferred server with host matching credentials url
        @initiating_server = select_initiating_server

        ##
        # Fetch credentials post from initiating server
        @initiating_credentials_post = fetch_initiating_credentials_post

        ##
        # Verify relationship#initial post exists on initiating server
        # and is accessible via fetched credentials
        verify_relationship!

        ##
        # Store initiating meta post
        save_initiating_post(Utils::Hash.symbolize_keys(initiating_meta_post))

        ##
        # Store credentials post for initial relationship post
        save_initiating_post(initiating_credentials_post)

        ##
        # Create new relationship post (without fragment) mentioning initial relationship post
        relationship_post = create_relationship_post

        ##
        # Create credentials post mentioning new relationship post
        credentials_post = Model::Credentials.generate(current_user, relationship_post)

        ##
        # Link credentials post for new relationship post in response header
        credentials_url = Utils.expand_uri_template(current_user.preferred_server['urls']['post'],
          :entity => current_user.entity,
          :post => credentials_post.public_id
        )
        env['response.links'] ||= []
        env['response.links'].push(
          :url => Utils.sign_url(current_user.server_credentials, credentials_url),
          :rel => CREDENTIALS_LINK_REL
        )

        ##
        # Respond with initial relationship post (request payload)
        env['response'] = {
          :post => env['data']
        }
        env['response.headers'] ||= {}
        env['response.headers']['Content-Type'] = POST_CONTENT_TYPE % env['data']['type']

        env
      end

      private

      def halt!(status, message, attributes = {})
        raise Middleware::Halt.new(status, message, attributes)
      end

      def parse_credentials_link
        unless link = env['request.links'].find { |link| link[:rel] == CREDENTIALS_LINK_REL }
          halt!(400, "Expected link to credentials post!")
        end

        link[:url]
      end

      def perform_discovery
        unless meta = TentClient.new(initiating_entity_uri).server_meta_post
          halt!(400, "Discovery of entity #{initiating_entity_uri.inspect} failed!")
        end

        meta['post']
      end

      def select_initiating_server
        # Sort servers by preference (lowest first)
        sorted_servers = initiating_meta_post['content']['servers'].sort_by { |s| s['preference'] }

        # Find server with matching host
        uri = URI(initiating_credentials_url)
        server = sorted_servers.find { |server|
          post_uri = URI(server['urls']['post'].gsub(/[{}]/, ''))

          (post_uri.scheme == uri.scheme) && (post_uri.host == uri.host) && (post_uri.port == uri.port)
        }

        unless server
          port_regex = [443, 80].include?(uri.port) ? "" : ":#{uri.port}"
          diff = [{
            :op => "add",
            :path => "/content/servers/urls/~/post",
            :value => "/^#{Regexp.escape(uri.scheme)}:\/\/#{Regexp.escape(uri.host)}#{port_regex}/",
            :type => "regexp"
          }]
          halt!(400, "Matching server not found!", :diff => diff, :post => initiating_meta_post)
        end

        server
      end

      def fetch_initiating_credentials_post
        res = Faraday.get(initiating_credentials_url) do |request|
          request.headers['Accept'] = POST_CONTENT_TYPE % CREDENTIALS_MIME_TYPE
        end

        wrapped_post = Utils::Hash.symbolize_keys(Yajl::Parser.parse(res.body))
        post = wrapped_post[:post]

        unless TentType.new(post[:type]).base == TentType.new(CREDENTIALS_MIME_TYPE).base
          if wrapped_post.has_key?(:error)
            halt!(400, "Invalid credentials post! (#{wrapped_post[:error]})", wrapped_post)
          else
            halt!(400, "Invalid credentials post!", post)
          end
        end

        diff = SchemaValidator.diff(post[:type], Utils::Hash.stringify_keys(post))
        unless diff.empty?
          halt!(400, "Invalid credentials post format!", :diff => diff, :post => post)
        end

        post
      rescue Faraday::Error::TimeoutError, Faraday::Error::ConnectionFailed
        halt!(400, "Failed to fetch credentials post from #{initiating_credentials_url.inspect}!")
      rescue Yajl::ParseError
        halt!(400, "Invalid credentials post encoding!", :post => res.body)
      end

      def verify_relationship!
        post = initiating_relationship_post

        # use the same server as credentials post
        _meta_post = Utils::Hash.deep_dup(initiating_meta_post)
        _meta_post['content']['servers'] = [initiating_server]

        client = TentClient.new(initiating_entity_uri,
          :server_meta => _meta_post,
          :credentials => {
            :id => initiating_credentials_post[:id],
            :hawk_key => initiating_credentials_post[:content][:hawk_key],
            :hawk_algorithm => initiating_credentials_post[:content][:hawk_algorithm]
          }
        )

        res = client.post.get(post[:entity], post[:id]) do |request|
          request.headers['Accept'] = POST_CONTENT_TYPE % post[:type]
        end

        unless res.status == 200
          halt!(400, "Failed to fetch relationship post from #{res.env[:url].to_s.inspect}!",
            :response_status => res.status,
            :response_body => res.body
          )
        end
      end

      def save_initiating_post(data)
        type, base_type = Model::Type.find_or_create(data[:type])
        received_at_timestamp = Utils.timestamp

        attrs = {
          :user_id => current_user.id,
          :entity_id => initiating_entity.id,
          :entity => initiating_entity_uri,

          :type => data[:type],
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => data[:version][:published_at],
          :version_received_at => received_at_timestamp,
          :published_at => data[:published_at],
          :received_at => received_at_timestamp,

          :version => data[:version][:id],

          :content => data[:content]
        }

        attrs[:mentions] = data[:mentions] if Array === data[:mentions]
        attrs[:refs] = data[:refs] if Array === data[:refs]

        post = Model::Post.create(attrs)

        if attrs[:mentions]
          post.create_mentions(attrs[:mentions])
        end

        post
      end

      def create_relationship_post
        type, base_type = Model::Type.find_or_create(RELATIONSHIP_MIME_TYPE)
        published_at_timestamp = Utils.timestamp

        attrs = {
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_base_id => base_type.id,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp
        }

        attrs[:mentions] = [Utils::Hash.slice(initiating_relationship_post, :entity, :type).merge(
          :post => initiating_relationship_post[:id]
        )]

        post = Model::Post.create(attrs)

        post.create_mentions(attrs[:mentions])

        post
      end
    end

  end
end
