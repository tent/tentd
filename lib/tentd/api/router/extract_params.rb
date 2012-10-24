module TentD
  class API
    module Router
      class ExtractParams
        attr_accessor :pattern, :keys

        def initialize(app, pattern, keys)
          @app, @pattern, @keys = app, pattern, keys
        end

        def call(env)
          add_request(env)
          extract_params(env)
          env['tent.entity'] ||= ENV['TENT_ENTITY']
          @app.call(env)
        end

        private

        def add_request(env)
          env['request'] = Rack::Request.new(env)
        end

        def extract_params(env)
          route = env[Rack::Mount::Prefix::KEY]
          route = '/' if route.empty?
          return unless match = pattern.match(route)
          values = match.captures.to_a.map { |v| URI.decode_www_form_component(v) if v }

          params = env['request'].params.dup

          if values.any?
            params.merge!('captures' => values)
            keys.zip(values) { |k,v| Array === params[k] ? params[k] << v : params[k] = v if v }
          end

          begin
            if env['CONTENT_TYPE'].to_s.split(';').first =~ /\bjson\Z/
              params['data'] = env['data'] || JSON.parse(env['rack.input'].read)
            elsif env['CONTENT_TYPE'] =~ /\Amultipart/
              key, data = params.find { |k,p| p[:type].split(';').first == MEDIA_TYPE }
              params.delete(key)
              params['data'] = JSON.parse(data[:tempfile].read) if data
              params['attachments'] = get_attachments(params)
            end
          rescue JSON::ParserError
          end

          env['params'] = indifferent_params(params)
        end

        def get_attachments(params)
          params.inject([]) { |a,(key,value)|
            if attachment?(value)
              a << value.merge(:name => key)
            elsif value.kind_of?(Hash)
              a += value.select { |k,v| attachment?(v) }.map { |k,v| v.merge(:name => key) }
            end
            a
          }
        end

        def attachment?(v)
          v.kind_of?(Hash) && v[:tempfile].kind_of?(Tempfile)
        end

        # Enable string or symbol key access to the nested params hash.
        def indifferent_params(object)
          case object
          when Hash
            new_hash = indifferent_hash
            object.each { |key, value| new_hash[key] = indifferent_params(value) }
            new_hash
          when Array
            object.map { |item| indifferent_params(item) }
          else
            object
          end
        end

        # Creates a Hash with indifferent access.
        def indifferent_hash
          Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
        end
      end
    end
  end
end
