module TentD
  class API

    class GetAttachment < Middleware
      def action(env)
        params = env['params']
        request_proxy_manager = env['request_proxy_manager']

        if (params[:entity] != env['current_user'].entity) && !request_proxy_manager.can_read?(params[:entity])
          halt!(404, "Not Found")
        end

        proxy_condition = if (params[:entity] == env['current_user'].entity)
          :never
        else
          request_proxy_manager.proxy_condition
        end

        unless proxy_condition == :always
          attachment, post_attachment = lookup_attachment(env)
        else
          attachment = nil
        end

        if !attachment && proxy_condition != :never && request_proxy_manager.can_proxy?(params[:entity])
          # proxy request
          status, headers, body = request_proxy_manager.request(params[:entity]) do |client|
            client.attachment.get(params[:entity], params[:digest])
          end
          return [status, headers, body]
        elsif !attachment
          halt!(404, "Not Found")
        end

        env['response'] = attachment
        (env['response.headers'] ||= {})['Content-Length'] = attachment.size.to_s
        env['response.headers']['Content-Type'] = post_attachment.content_type
        env
      end

      private

      def lookup_attachment(env)
        params = env['params']

        attachment = nil

        attachment = Model::Attachment.find_by_digest(params[:digest])
        return unless attachment

        posts = Model::Post.
          qualify.
          join(:posts_attachments, :posts__id => :posts_attachments__post_id).
          where(:posts_attachments__digest => attachment.digest, :posts__user_id => env['current_user'].id).
          order(Sequel.desc(:posts__received_at)).
          all
        return unless posts.any?

        unless post = posts.find { |post| Authorizer.new(env).read_authorized?(post) }
          return
        end

        post_attachment = Model::PostsAttachment.where(:post_id => post.id).first

        [attachment, post_attachment]
      end
    end

  end
end
