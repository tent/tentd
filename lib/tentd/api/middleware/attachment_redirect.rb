module TentD
  class API

    class AttachmentRedirect < Middleware
      def action(env)
        unless Model::Post === env['response.post']
          env.delete('response.post')
          return env
        end

        post = env.delete('response.post')
        params = env['params']

        accept = env['HTTP_ACCEPT'].to_s.split(';').first

        attachments = post.attachments.select { |a| a['name'] == params[:name] }

        unless accept == '*/*'
          attachments = attachments.select { |a| a['content_type'] == accept }
        end
        return env if attachments.empty?

        attachment = attachments.first

        attachment_url = Utils.expand_uri_template(env['current_user'].preferred_server['urls']['attachment'],
          :entity => post.entity,
          :digest => attachment['digest']
        )

        (env['response.headers'] ||= {})['Location'] = attachment_url
        env['response.headers']['Attachment-Digest'] = attachment['digest']
        env['response.status'] = 302

        env
      end
    end

  end
end
