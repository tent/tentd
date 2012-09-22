require 'time'

module TentD
  class API
    module Router
      class CachingHeaders
        CACHE_CONTROL = ', max-age=0, must-revalidate'.freeze
        CACHE_CONTROL_PUBLIC = ('public' + CACHE_CONTROL).freeze
        CACHE_CONTROL_PRIVATE = ('private' + CACHE_CONTROL).freeze

        def initialize(app)
          @app = app
        end

        def call(env)
          return @app.call(env) unless %w(GET HEAD).include?(env['REQUEST_METHOD'])
          last_modified_at = last_modified(env.response)
          if_modified_since = env['HTTP_IF_MODIFIED_SINCE']
          if if_modified_since && last_modified_at && Time.httpdate(if_modified_since) >= last_modified_at
            return [304, {}, []]
          end
          status, headers, body = @app.call(env)
          headers['Last-Modified'] ||= last_modified_at.httpdate if last_modified_at
          headers['Cache-Control'] ||= cache_control(env.response) if cache_control(env.response)
          @last_modified = @cache_control = nil
          [status, headers, body]
        end

        private

        def last_modified(object)
          @last_modified ||= if object.respond_to?(:updated_at)
            t = object.updated_at
            t.respond_to?(:to_time) ? t.to_time : t
          elsif object.kind_of?(Enumerable) && object.first.respond_to?(:updated_at)
            object.map { |o|
              t = o.updated_at
              t.respond_to?(:to_time) ? t.to_time : t
            }.sort.last
          end
        end

        def cache_control(object)
          @cache_control ||= if object.respond_to?(:public) || object.respond_to?(:permissions)
            public?(object) ? CACHE_CONTROL_PUBLIC : CACHE_CONTROL_PRIVATE
          elsif object.kind_of?(Enumerable) && (object.first.respond_to?(:public) || object.first.kind_of?(Hash) && object.first['permissions'])
            object.map { |o| public?(o) }.uniq == [true] ? CACHE_CONTROL_PUBLIC : CACHE_CONTROL_PRIVATE
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
