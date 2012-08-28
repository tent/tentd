require 'rack/mount'

class Rack::Mount::RouteSet
  def merge_routes(routes)
    routes.each { |r| merge_route(r) }
    rehash
  end

  def merge_route(route)
    @routes << route

    @recognition_key_analyzer << route.conditions

    @named_routes[route.name] = route if route.name
    @generation_route_keys << route.generation_keys

    expire!
    route
  end
end

module TentServer
  class API
    module Router
      autoload :ExtractParams, 'tent-server/api/router/extract_params'
      autoload :SerializeResponse, 'tent-server/api/router/serialize_response'

      def self.included(base)
        base.extend(ClassMethods)
      end

      def call(env)
        self.class.routes.call(env)
      end

      module ClassMethods
        def mount(klass)
          routes.merge_routes klass.routes.instance_variable_get("@routes")
        end

        def routes
          @routes ||= Rack::Mount::RouteSet.new
        end

        #### This section heavily "inspired" by sinatra

        # Defining a `GET` handler also automatically defines
        # a `HEAD` handler.
        def get(path, opts={}, &block)
          route('GET', path, opts, &block)
          route('HEAD', path, opts, &block)
        end

        def put(path, opts={}, &bk)     route 'PUT',     path, opts, &bk end
        def post(path, opts={}, &bk)    route 'POST',    path, opts, &bk end
        def delete(path, opts={}, &bk)  route 'DELETE',  path, opts, &bk end
        def head(path, opts={}, &bk)    route 'HEAD',    path, opts, &bk end
        def options(path, opts={}, &bk) route 'OPTIONS', path, opts, &bk end
        def patch(path, opts={}, &bk)   route 'PATCH',   path, opts, &bk end

        private

        def route(verb, path, options={}, &block)
          path, params = compile_path(path)

          return if route_exists?(verb, path)

          builder = Rack::Builder.new(SerializeResponse.new)
          builder.use(AuthenticationLookup)
          builder.use(AuthenticationVerification)
          builder.use(AuthenticationFinalize)
          builder.use(ExtractParams, path, params)
          block.call(builder)

          routes.add_route(builder.to_app, :request_method => verb, :path_info => path)
          routes.rehash
        end

        def route_exists?(verb, path)
          @added_routes ||= []
          return true if @added_routes.include?("#{verb}#{path}")
          @added_routes << "#{verb}#{path}"
          false
        end

        def compile_path(path)
          keys = []
          if path.respond_to? :to_str
            ignore = ""
            pattern = path.to_str.gsub(/[^\?\%\\\/\:\*\w]/) do |c|
              ignore << escaped(c).join if c.match(/[\.@]/)
              encoded(c)
            end
            pattern.gsub!(/((:\w+)|\*)/) do |match|
              if match == "*"
                keys << 'splat'
                "(.*?)"
              else
                keys << $2[1..-1]
                "([^#{ignore}/?#]+)"
              end
            end
            [/\A#{pattern}\z/, keys]
          elsif path.respond_to?(:keys) && path.respond_to?(:match)
            [path, path.keys]
          elsif path.respond_to?(:names) && path.respond_to?(:match)
            [path, path.names]
          elsif path.respond_to? :match
            [path, keys]
          else
            raise TypeError, path
          end
        end
      end
    end
  end
end
