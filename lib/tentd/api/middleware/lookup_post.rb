module TentD
  class API

    class LookupPost < Middleware
      def action(env)
        params = env['params']
        request_proxy_manager = env['request_proxy_manager']

        proxy_condition = if (params[:entity] == env['current_user'].entity) || !['GET', 'HEAD'].include?(env['REQUEST_METHOD'])
          :never
        else
          request_proxy_manager.proxy_condition
        end

        post = unless proxy_condition == :always
          env['request.post_lookup_attempted'] = true

          if params['version'] && params['version'] != 'latest'
            Model::Post.first(:public_id => params[:post], :entity => params[:entity], :version => params['version'])
          else
            Model::Post.where(:public_id => params[:post], :entity => params[:entity]).order(Sequel.desc(:version_received_at)).first
          end
        end

        if !post && proxy_condition != :never && !env['request.post_list']
          # proxy request
          begin
            status, headers, body = request_proxy_manager.request(params[:entity]) do |client|
              client.post.get(params[:entity], params[:post])
            end
            return [status, headers, body]
          rescue Faraday::Error::TimeoutError
            if proxy_condition == :always
              res ||= Faraday::Response.new({})
              halt!(504, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
            end
          rescue Faraday::Error::ConnectionFailed
            if proxy_condition == :always
              res ||= Faraday::Response.new({})
              halt!(502, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
            end
          end
        else
          env['response.post'] = post
        end

        env
      end
    end

  end
end
