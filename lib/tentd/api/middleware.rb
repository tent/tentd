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
        error_response(404, 'Not Found')
      rescue Unauthorized
        error_response(403, 'Unauthorized')
      rescue Sequel::DatabaseError => e
        if ENV['RACK_ENV'] == 'test'
          raise
        elsif defined?(Airbrake)
          Airbrake.notify_or_ignore(e, :rack_env => env)
        else
          puts $!.inspect, $@
        end
        error_response(422, 'Invalid Attributes')
      rescue Sequel::ValidationFailed
        error_response(422, 'Invalid Attributes')
      rescue Exception => e
        if ENV['RACK_ENV'] == 'test'
          raise
        elsif defined?(Airbrake)
          Airbrake.notify_or_ignore(e, :rack_env => env)
        else
          puts $!.inspect, $@
        end
        error_response(500, 'Internal Server Error')
      end

      private

      def self_uri(env)
        uri = URI('')
        uri.host = env.HTTP_HOST.split(':').first
        uri.scheme = env['rack.url_scheme']
        uri.path = env.SCRIPT_NAME

        port = (env.HTTP_X_FORWARDED_PORT || env.SERVER_PORT).to_i
        uri.port = port unless [80, 443].include?(port)

        uri
      end

      def serialize_params(params)
        params.inject([]) { |m, (k,v)| m << "#{k}=#{URI.encode_www_form_component(v)}"; m }.join('&')
      end

      def error_response(status, error, headers = {})
        [status, headers.merge('Content-Type' => MEDIA_TYPE), [{ 'error' => error }.to_json]]
      end
    end
  end
end
