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
          status, headers, body = request_proxy_manager.request(params[:entity]) do |client|
            client.post.get(params[:entity], params[:post])
          end
          return [status, headers, body]
        else
          env['response.post'] = post
        end

        env
      end
    end

  end
end
