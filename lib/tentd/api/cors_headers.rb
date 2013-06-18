module TentD
  class API

    class CorsHeaders
      HEADERS = {
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Headers' => 'Server-Authorization, Count, ETag, Link',
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
      HEADERS = {
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Allow-Methods' => 'DELETE, GET, HEAD, PATCH, POST, PUT',
        'Access-Control-Allow-Headers' => 'Accept, Authorization, Cache-Control, Content-Type, If-Match, If-None-Match, Link',
        'Access-Control-Expose-Headers' => 'Count, Link, Server-Authorization, Content-Type',
        'Access-Control-Max-Age' => '2592000' # 30 days
      }.freeze

      def initialize(app)
        @app = app
      end

      def call(env)
        [200, HEADERS.dup, []]
      end
    end

  end
end
