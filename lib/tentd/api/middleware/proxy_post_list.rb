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

        _params = Utils::Hash.slice(params, :limit, :version)
        status, headers, body = request_proxy_manager.request(params[:entity]) do |client|
          client.post.get(params[:entity], params[:post], _params) do |request|
            request.headers['Accept'] = env['HTTP_ACCEPT']
          end
        end
        return [status, headers, body]
      rescue Faraday::Error::TimeoutError
        halt!(504, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
      rescue Faraday::Error::ConnectionFailed
        halt!(502, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
      end
    end

  end
end
