require 'time'

module TentD
  class API
    module Router
      class CachingHeaders
        def initialize(app)
          @app = app
        end

        def call(env)
          return @app.call(env) unless %w(GET HEAD).include?(env['REQUEST_METHOD'])
          last_modified_at = last_modified(env.response)
          if_modified_since = env['HTTP_IF_MODIFIED_SINCE']
          if if_modified_since && Time.httpdate(if_modified_since) >= last_modified_at
            return [304, {}, nil]
          end
          status, headers, body = @app.call(env)
          headers['Last-Modified'] ||= last_modified_at.httpdate if last_modified_at
          headers['Cache-Control'] ||= cache_control(env.response) if cache_control(env.response)
          [status, headers, body]
        end

        private

        def last_modified(object)
          if object.respond_to?(:updated_at)
            object.updated_at
          elsif object.kind_of?(Enumerable) && object.first.respond_to?(:updated_at)
            object.map { |o| o.updated_at }.sort.last
          end
        end

        def cache_control(object)
          if object.respond_to?(:public) || object.respond_to?(:permissions)
            public?(object) ? 'public' : 'private'
          elsif object.kind_of?(Enumerable) && (object.first.respond_to?(:public) || object.first.kind_of?(Hash) && object.first['permissions'])
            object.map { |o| public?(o) }.uniq == [true] ? 'public' : 'private'
          end
        end

        def public?(object)
          object.respond_to?(:public) && object.public ||
          object.kind_of?(Hash) && (object['public'] || object['permissions'] && object['permissions']['public'])
        end
      end
    end
  end
end
