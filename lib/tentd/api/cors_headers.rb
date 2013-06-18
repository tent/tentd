module TentD
  class API

    class CorsHeaders
      HEADERS = {
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Methods' => 'GET, POST, HEAD, PUT, DELETE, PATCH, OPTIONS',
        'Access-Control-Allow-Headers' => 'Content-Type, Accept, Authorization',
        'Access-Control-Expose-Headers' => 'Count, Link, Server-Authorization, Content-Type',
        'Access-Control-Max-Age' => '2592000' # 30 days
      }.freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)

        headers.merge!(HEADERS.dup) if env['HTTP_ORIGIN']

        [status, headers, body]
      end
    end

    class CorsPreflight
      def initialize(app)
        @app = app
      end

      def call(env)
        [200, CorsHeaders::HEADERS.dup, []]
      end
    end

  end
end
