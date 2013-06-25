module TentD
  module Worker

    class NotificationAppDeliverer
      include Sidekiq::Worker

      sidekiq_options :retry => 10

      DeliveryFailure = Class.new(StandardError)

      MAX_RELATIONSHIP_RETRY = 10.freeze

      def perform(post_id, app_id)
        unless post = Model::Post.where(:id => post_id).first
          logger.info "Post(#{post_id}) deleted"
          return
        end

        unless app = Model::App.where(:id => app_id).first
          logger.info "App(#{app_id}) deleted"
          return
        end

        unless app_credentials = Model::Post.where(:id => app.credentials_post_id).first
          logger.info "App(#{app_id}) credentials Post(#{app.credentials_post_id.inspect}) missing"
          return
        end

        logger.info "Delivering Post(#{post_id}) to App(#{app_id})"

        client = TentClient.new(nil, :credentials => Model::Credentials.slice_credentials(app_credentials))
        client.http.put(app.notification_url, {}, post.as_json(
          :env => {
            'current_auth' => app_credentials,
            'current_auth.resource' => app
          }
        )) do |request|
          request.headers['Content-Type'] = %(application/vnd.tent.post.v0+json; type="%s"; rel="https://tent.io/rels/notification") % post.type
        end

      rescue URI::InvalidURIError => e
        logger.error "Failed to deliver Post(#{post_id}) to App(#{app_id}): #{e.inspect} #{app.notification_url.inspect}"
        raise
      end

      def retries_exhausted(post_id, entity)
        # TODO: update delivery failure post
      end
    end

  end
end
