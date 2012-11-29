require 'hashie'

module TentD
  class API
    class Middleware
      include Authorizable

      NotFound = Class.new(Error)

      def initialize(app)
        @app = app
      end

      def call(env)
        env = Hashie::Mash.new(env) unless env.kind_of?(Hashie::Mash)
        response = action(env)
        response.kind_of?(Hash) ? @app.call(response) : response
      rescue NotFound
        [404, {}, [{ 'error' => 'Not Found' }.to_json]]
      rescue Unauthorized
        [403, {}, [{ 'error' => 'Unauthorized' }.to_json]]
      rescue Sequel::ValidationFailed, Sequel::DatabaseError
        [422, {}, [{ 'error' => 'Invalid Attributes' }.to_json]]
      rescue Exception => e
        if ENV['RACK_ENV'] == 'test'
          raise
        elsif defined?(Airbrake)
          Airbrake.notify_or_ignore(e, :rack_env => env)
        else
          puts $!.inspect, $@
        end
        [500, {}, [{ 'error' => 'Internal Server Error' }.to_json]]
      end

      private

      def self_uri(env)
        uri = URI('')
        uri.host = env.HTTP_HOST
        uri.scheme = env['rack.url_scheme']

        port = (env.HTTP_X_FORWARDED_PORT || env.SERVER_PORT).to_i
        uri.port = port unless [80, 443].include?(port)

        uri
      end

      def serialize_params(params)
        "#{params.inject([]) { |m, (k,v)| m << "#{k}=#{URI.encode_www_form_component(v)}"; m }.join('&')}"
      end
    end
  end
end
