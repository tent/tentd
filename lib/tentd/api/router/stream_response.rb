require 'json'

# Fix Puma treating empty BodyProxies as non-empty
module Rack
  class BodyProxy
    def ==(other)
      if other == [] and @body == []
        true
      else
        super
      end
    end
  end
end

module TentD
  class API
    module Router
      class StreamResponse
        LENGTH_PREFIXED_JSON_TYPE = 'application/vnd.tent.v0+length-prefixed-json'.freeze
        
        def matches?(env)
          env['HTTP_ACCEPT'] == LENGTH_PREFIXED_JSON_TYPE
        end
        
        def call(env)
          status = env['response.status'] || (env.response ? 200 : 404)
          
          if !env.can_stream
            if env.response
              status = 400
              response = "Streaming is not available for this resource"
            else
              status = 404
              response = "Not found"
            end
          end

          if (400...600).include?(status)
            return serialize_error_response(status, env['response.headers'], response)
          end

          raise 'not implemented' unless status == 200

          start_stream(env)
        end

        private

        def start_stream(env)
          user = TentD::Model::User.current

          Thread.new do 
            TentD::Model::User.current = user
            begin
              stream_response(env)
            rescue Errno::EPIPE
              # client disconnected
            end
          end

          [-1, {}, []]
        end

        def stream_response(env)
          socket = env['puma.socket']
          
          headers = { "Content-Type" => LENGTH_PREFIXED_JSON_TYPE }
          headers.merge env['response.headers']

          serializer = SerializeResponse.new
          
          # Just a tad hackish
          socket.write "HTTP/1.1 200 OK\r\n"
          headers.each do |k,v|
            socket.write "#{k}: #{v}\r\n"
          end
          socket.write "\r\n"
          
          db = Sequel.connect(ENV['DATABASE_URL'], :logger => Logger.new(STDOUT))
          db.listen(TentD::Streaming::POSTGRES_CHANNEL, loop: true) do |channel, backend, payload|
            post_id = payload

            params = env.params.dup
            params[:id] = post_id
            
            if env.current_auth # TODO: mirror API of GET /posts
              post = Model::Post.fetch_all(params, env.current_auth).first
            else
              post = Model::Post.fetch_with_permissions(params, env.current_auth).first
            end

            if post
              env.response = post
              serialized = serializer.serialize_response(env)
              socket.write "#{serialized.length}\n"
              socket.write "#{serialized}\n"
            end
          end
        end

        def serialize_error_response(status, headers, response)
          unless response
            status = 404
            response = 'Not Found'
          end

          [status, headers.merge('Content-Type' => MEDIA_TYPE), { :error => response }.to_json]
        end

      end
    end
  end
end
