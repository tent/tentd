module TentD
  class API
    module Router
      class CorsHeaders
        def initialize(app)
          @app = app
        end

        def call(env)
          if env['HTTP_METHOD'] == 'OPTIONS'
            headers = {
              'Access-Control-Allow-Origin' => '*',
              'Access-Control-Allow-Methods' => 'GET, POST, HEAD, PUT, DELETE, PATCH, OPTIONS',
              'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
              'Access-Control-Max-Age' => '2592000' # 30 days
            }
            return [200, headers, []]
          end

          status, headers, body = @app.call(env)
          headers.merge!(
            'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
          ) if env['HTTP_ORIGIN']
          [status, headers, body]
        end
      end
    end
  end
end
