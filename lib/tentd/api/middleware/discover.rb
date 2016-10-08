module TentD
  class API
    class Discover < Middleware
      def action(env)
        unless Authorizer.new(env).proxy_authorized?
          halt!(403, "Unauthorized")
        end

        params = env['params']

        unless params[:entity] && params[:entity].match(URI.regexp)
          halt!(400, "Entity param must be a valid url: #{Yajl::Encoder.encode(params[:entity])}")
        end

        status, headers, body = env['request_proxy_manager'].request(params[:entity]) do |client|
          TentClient::Discovery.new(client, params[:entity], :skip_serialization => true).discover(:return_response => true)
        end

        [status, headers, body]
      end
    end
  end
end
