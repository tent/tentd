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
          proxy_client = request_proxy_manager.proxy_client(params[:entity])

          begin
            res = proxy_client.attachment.get(params[:entity], params[:digest])

            body = res.body.respond_to?(:each) ? res.body : [res.body]
            return [res.status, res.headers, body]
          rescue Faraday::Error::TimeoutError
            halt!(504, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
          rescue Faraday::Error::ConnectionFailed
            halt!(502, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
          end
        elsif !attachment
          halt!(404, "Not Found")
        end

        env['response'] = attachment.data.lit
        (env['response.headers'] ||= {})['Content-Length'] = attachment.data.bytesize.to_s
        env['response.headers']['Content-Type'] = post_attachment.content_type
        env
      end

      private

      def lookup_attachment(env)
        params = env['params']

        attachment = Model::Attachment.where(:digest => params[:digest]).first
        return unless attachment

        post_attachment = Model::PostsAttachment.where(:attachment_id => attachment.id).first
        return unless post_attachment

        post = Model::Post.where(:id => post_attachment.post_id, :user_id => env['current_user'].id).first
        return unless post

        unless Authorizer.new(env).read_authorized?(post)
          return
        end

        [attachment, post_attachment]
      end
    end

  end
end
