require 'hashie'

module TentD
  class API
    class Middleware
      include Authorizable

      def initialize(app)
        @app = app
      end

      def call(env)
        env = Hashie::Mash.new(env) unless env.kind_of?(Hashie::Mash)
        response = action(env)
        response.kind_of?(Hash) ? @app.call(response) : response
      rescue Unauthorized
        [403, {}, ['Unauthorized']]
      rescue DataMapper::SaveFailureError, DataObjects::IntegrityError
        [422, {}, ['Invalid Attributes']]
      rescue
        raise if ENV['RACK_ENV'] == 'test'
        puts $!.inspect, $@
        [500, {}, ['Internal Server Error']]
      end
    end
  end
end
