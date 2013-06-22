module TentD
  class API

    class LookupPost < Middleware
      def action(env)
        params = env['params']
        request_proxy_manager = env['request_proxy_manager']

        proxy_condition = if (params[:entity] == env['current_user'].entity) || (env['REQUEST_METHOD'] != 'GET')
          :never
        else
          request_proxy_manager.proxy_condition
        end

        post = unless proxy_condition == :always
          if params['version'] && params['version'] != 'latest'
            Model::Post.first(:public_id => params[:post], :entity => params[:entity], :version => params['version'])
          else
            Model::Post.where(:public_id => params[:post], :entity => params[:entity]).order(Sequel.desc(:version_received_at)).first
          end
        end

        if !post && proxy_condition != :never
          # proxy request
          proxy_client = request_proxy_manager.proxy_client(params[:entity], :skip_response_serialization => true)

          begin
            res = proxy_client.post.get(params[:entity], params[:post])

            body = res.body.respond_to?(:each) ? res.body : [res.body]
            return [res.status, res.headers, body]
          rescue Faraday::Error::TimeoutError
            halt!(504, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
          rescue Faraday::Error::ConnectionFailed
            halt!(502, "Failed to proxy request: #{res.env[:method].to_s.upcase} #{res.env[:url].to_s}")
          end
        else
          env['response.post'] = post
        end

        env
      end
    end

  end
end
