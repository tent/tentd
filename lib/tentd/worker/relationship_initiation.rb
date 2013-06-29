module TentD
  module Worker

    class RelationshipInitiation
      include Sidekiq::Worker

      sidekiq_options :retry => 10

      InitiationFailure = Class.new(StandardError)
      DiscoveryFailure = Class.new(InitiationFailure)
      DeliveryFailure = Class.new(InitiationFailure)
      InvalidResponse = Class.new(InitiationFailure)
      EntityUnreachable = Class.new(InitiationFailure)

      attr_accessor :retry_count

      def perform(user_id, target_entity_id, deliver_post_id=nil)
        # user no longer exists, abort
        return unless current_user = Model::User.where(:id => user_id).first

        target_entity = Model::Entity.where(:id => target_entity_id).first.entity

        relationship = begin
          Model::Relationship.create(:user_id => user_id, :entity_id => target_entity_id)
        rescue Sequel::UniqueConstraintViolation
        end

        # already created
        unless relationship
          logger.info "Relationship(#{user_id}, #{target_entity_id}) already exists"

          queue_post_delivery(deliver_post_id, target_entity, target_entity_id) if deliver_post_id

          return
        end

        ##
        # Create relationship#initial post with credentials
        ##

        Model::Relationship.create_initial(current_user, target_entity, relationship)

        relationship_data = relationship.post.as_json
        credentials_post = relationship.credentials_post

        ##
        # Perform discovery on target entity
        ##

        client = TentClient.new(target_entity)

        discovery_res = TentClient::Discovery.discover(client, target_entity, :return_response => true)

        unless discovery_res.success?
          discovery_error = "Failed to perform discovery on #{target_entity.inspect}: #{discovery_res.env[:method].to_s.upcase} #{discovery_res.env[:url].to_s} failed with status #{discovery_res.status}"
        end

        if discovery_res.status > 500
          raise EntityUnreachable.new(discovery_error)
        end

        if discovery_res.success? && (Hash === discovery_res.body)
          client = TentClient.new(target_entity, :server_meta => discovery_res.body['post'])
        else
          raise DiscoveryFailure.new(discovery_error)
        end

        ##
        # Send relationship#initial post to target entity's server
        ##

        res = client.post.update(relationship_data[:entity], relationship_data[:id], relationship_data, params = {},
          :notification => true
        ) do |request|
          url = TentD::Utils.expand_uri_template(
            current_user.preferred_server['urls']['post'],
            :entity => current_user.entity,
            :post => credentials_post.public_id
          )
          link = %(<#{TentD::Utils.sign_url(current_user.server_credentials, url)}>; rel="https://tent.io/rels/credentials")
          request.headers['Link'] ? request.headers['Link'] << ", #{link}" : request.headers['Link'] = link
        end

        unless res.status == 200
          raise DeliveryFailure.new("Got(status: #{res.status} body: #{res.body.inspect}) performing PUT #{res.env[:url].to_s} with #{relationship_data.inspect}")
        end

        unless (Hash === res.body) && (Hash === res.body['post']) && (relationship_data[:type] == res.body['post']['type'])
          raise InvalidResponse.new("Invalid relationship response body: #{res.body.inspect}")
        end

        ##
        # Fetch credentials linked in response
        ##

        links = TentClient::LinkHeader.parse(res.headers['Link'].to_s).links
        credentials_url = links.find { |link| link[:rel] == 'https://tent.io/rels/credentials' }

        unless credentials_url
          raise InvalidResponse.new("Expected credentials link, Got #{res.headers['Link'].inspect}")
        end
        credentials_url = credentials_url.uri

        res = client.http.get(credentials_url)

        unless res.status == 200
          raise InvalidResponse.new("Failed to fetch credentials via GET #{credentials_url.inspect}")
        end

        unless (Hash === res.body) && (Hash === res.body['post']) && (res.body['post']['type'] == "https://tent.io/types/credentials/v0#")
          raise InvalidResponse.new("Invalid credentials response body: #{res.body.inspect}")
        end

        remote_credentials_post = res.body['post']

        ##
        # Fetch remote relationship post via credentials' mentions
        ##

        mention = remote_credentials_post['mentions'].to_a.find { |m|
          m['type'] == 'https://tent.io/types/relationship/v0#'
        }

        unless mention
          raise InvalidResponse.new("Expected relationship post to be mentioned in credentials response: #{remote_credentials_post.inspect}")
        end

        # setup authenticated client
        client = TentClient.new(target_entity,
          :server_meta => client.server_meta_post,
          :credentials => {
            :id => remote_credentials_post['id'],
            :hawk_key => remote_credentials_post['content']['hawk_key'],
            :hawk_algorithm => remote_credentials_post['content']['hawk_algorithm']
          }
        )

        # fetch remote relationship post
        res = client.post.get(target_entity, mention['post'])

        unless res.status == 200
          raise InvalidResponse.new("Failed to fetch relationship post via GET #{res.env[:url].to_s.inspect}\n#{res.headers.inspect}\n\n #{res.status} #{res.body.inspect}")
        end

        unless (Hash === res.body) && (Hash === res.body['post']) && res.body['post']['type'] == "https://tent.io/types/relationship/v0#"
          raise InvalidResponse.new("Invalid response body fetching relationship post: #{res.body.inspect}")
        end

        remote_relationship_post = res.body['post']

        ##
        # Save meta post
        remote_meta_post = save_remote_post(current_user, target_entity, client.server_meta_post)

        ##
        # Update relationship post (remove fragment)
        relationship.meta_post_id = remote_meta_post.id
        relationship.remote_credentials_id = remote_credentials_post['id']
        relationship.remote_credentials = {
          'id' => remote_credentials_post['id'],
          'hawk_key' => remote_credentials_post['content']['hawk_key'],
          'hawk_algorithm' => remote_credentials_post['content']['hawk_algorithm']
        }
        relationship.finalize

        ##
        # Deliver relationship post
        NotificationDeliverer.perform_async(relationship.post_id, target_entity, target_entity_id)

        ##
        # Deliver dependent post
        NotificationDeliverer.perform_async(deliver_post_id, target_entity, target_entity_id)
      rescue EntityUnreachable
        if retry_count == 0 && deliver_post_id
          delivery_failure(target_entity, deliver_post_id, 'temporary', 'unreachable')
        end

        raise
      rescue DiscoveryFailure
        if retry_count == 0 && deliver_post_id
          delivery_failure(target_entity, deliver_post_id, 'temporary', 'discovery_failed')
        end

        raise
      rescue TentClient::ServerNotFound, TentClient::MalformedServerMeta => e
        if retry_count == 0 && deliver_post_id
          delivery_failure(target_entity, deliver_post_id, 'temporary', 'discovery_failed')
        end

        error = DiscoveryFailure.new(e.inspect)
        error.set_backtrace(e.backtrace)
        raise error
      rescue InitiationFailure
        if retry_count == 0 && deliver_post_id
          delivery_failure(target_entity, deliver_post_id, 'temporary', 'relationship_failed')
        end

        raise
      end

      def retries_exhausted(user_id, target_entity_id, deliver_post_id=nil)
        if deliver_post_id
          queue_post_delivery(deliver_post_id, target_entity, target_entity_id)
        end

        # TODO: destroy relationship and subscriptions
      end

      private

      def save_remote_post(current_user, entity, post)
        attrs = Model::PostBuilder.build_attributes({
          'data' => post,
          'current_user' => current_user,
        }, { :entity => entity, :public_id => post['id'], :notification => true })
        Model::Post.create(attrs)
      end

      def queue_post_delivery(post_id, entity, entity_id)
        logger.info "Queuing Post(#{post_id}) for delivery"

        NotificationDeliverer.perform_in(5, post_id, entity, entity_id)
      end

      def delivery_failure(target_entity, post_id, status, reason)
        return unless post = Model::Post.where(:id => post_id).first

        logger.info "Creating #{status.inspect} delivery failure for Post(#{post_id}) to Entity(#{target_entity}): #{reason}"

        Model::DeliveryFailure.find_or_create(target_entity, post, status, reason)
      end
    end

  end
end
