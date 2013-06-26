module TentD
  class API

    class ProxyPostList < Middleware
      def action(env)
        unless [MENTIONS_CONTENT_TYPE, CHILDREN_CONTENT_TYPE, VERSIONS_CONTENT_TYPE].include?(env['HTTP_ACCEPT'])
          return env
        end

        env['request.post_list'] = true

        params = env['params']
        request_proxy_manager = env['request_proxy_manager']

        return env if params[:entity] == env['current_user'].entity
        return env if request_proxy_manager.proxy_condition == :never
        return env if request_proxy_manager.proxy_condition == :on_miss && !env['request.post_lookup_attempted']

        proxy_client = request_proxy_manager.proxy_client(params[:entity], :skip_response_serialization => true)

        _params = Utils::Hash.slice(params, :limit, :version)
        res = proxy_client.post.get(params[:entity], params[:post], _params) do |request|
          request.headers['Accept'] = env['HTTP_ACCEPT']
        end

        body = res.body.respond_to?(:each) ? res.body : [res.body]
        return [res.status, res.headers, body]
      rescue Faraday::Error::TimeoutError
        halt!(504, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
      rescue Faraday::Error::ConnectionFailed
        halt!(502, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
      end
    end

  end
end
