module TentServer
  class API
    module Router
      autoload :ExtractParams, 'tent-server/api/router/extract_params'
      autoload :SerializeResponse, 'tent-server/api/router/serialize_response'

      def self.included(base)
        base.extend(ClassMethods)
      end

      def call(env)
        @@routes.call(env)
      end

      module ClassMethods
        attr_accessor :routes

        def mount(klass)
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

          builder = Rack::Builder.new(SerializeResponse)
          builder.use(ExtractParams, path, params)
          block.call(builder)

          (@routes ||= Rack::Mount::RouteSet.new).add_route(builder.to_app, :request_method => verb, :path_info => path)
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
