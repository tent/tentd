module TentD
  class API

    class ProxyAttachmentRedirect < Middleware
      def action(env)
        params = env['params']
        request_proxy_manager = env['request_proxy_manager']

        return env if request_proxy_manager.proxy_condition == :never

        proxy_client = request_proxy_manager.proxy_client(params[:entity], :skip_response_serialization => true)

        _params = Utils::Hash.slice(params, :version)
        res = proxy_client.post.get_attachment(params[:entity], params[:post], params[:name], _params) do |request|
          request.headers['Accept'] = env['HTTP_ACCEPT']
        end

        body = res.body.respond_to?(:each) ? res.body : [res.body]

        if res.headers['Location']
          digest = res.headers['Attachment-Digest']
          headers = {
            'Location' => "/attachments/#{URI.encode_www_form_component(params[:entity])}/#{digest}"
          }
          return [302, headers, []]
        else
          halt!(404, "Not Found")
        end
      rescue Faraday::Error::TimeoutError
        halt!(504, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
      rescue Faraday::Error::ConnectionFailed
        halt!(502, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
      end
    end

  end
end
