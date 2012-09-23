module TentD
  class API
    module Router
      class CorsHeaders
        def initialize(app)
          @app = app
        end

        def call(env)
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
