module TentD
  class API
    module Router
      class EtagCheck
        def initialize(app)
          @app = app
        end

        def call(env)
          status, headers, body = @app.call(env)
          if !headers['ETag'].nil? && headers['ETag'] == env['HTTP_IF_NONE_MATCH'] && %w(GET HEAD).include?(env['HTTP_METHOD'])
            [304, headers, []]
          else
            [status, headers, body]
          end
        end
      end
    end
  end
end
