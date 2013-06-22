module TentD
  class API

    class SetRequestProxyManager < Middleware
      def action(env)
        env['request_proxy_manager'] = RequestProxyManager.new(env)
        env
      end
    end

  end
end
