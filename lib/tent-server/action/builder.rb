module TentServer
  module Action
    # Tent::Server::Action::Builder implements a small DSL to add middleware to the call stack.
    #
    # Example:
    #
    #  app = Tent::Server::Action::Builder.new.tap do |b|
    #    b.use Rack::CommonLogger
    #  end
    #
    #  app.call(env)
    class Builder
      # Specifies middleware to use in a stack.
      #
      #   class Middleware
      #     def initialize(app)
      #       @app = app
      #     end
      #
      #     def call(env)
      #       @app.call(env)
      #     end
      #   end
      #
      def use(middleware, *args, &block)
        (@stack ||= []) << proc { |app| middleware.new(app, *args, &block) }
      end

      def to_app
        app = lambda { |env| env }
        @stack.reverse.inject(app) { |a,e| e[a] }
      end

      def call(env)
        to_app.call(env)
      end
    end
  end
end
