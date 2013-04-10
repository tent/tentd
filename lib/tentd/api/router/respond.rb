module TentD
  class API
    module Router
      class Respond
        def call(env)
          if env.start_post_stream
            status = env['response.status'] || 200

            if (400...600).include?(status)
              return serialize_error_response(status, env['response.headers'], response)
            end

            raise 'not implemented' unless status == 200

            TentD::Streaming.start_post_stream(env)
            [-1, {}, []]
          else
            if env.stream_requested
              status = 400
              response = "Streaming is not available for this resource"
            end

            response = if env.response
              env.response.kind_of?(String) ? env.response : TentD::API::Serializer.serialize(env.response, env)
            end

            status = env['response.status'] || (response ? 200 : 404)
            headers = if env['response.type'] || status == 200 && response && !response.empty?
                        { 'Content-Type' => env['response.type'] || MEDIA_TYPE } 
                      else
                        {}
                      end.merge(env['response.headers'] || {})
            status, headers, response = serialize_error_response(status, headers, response) if (400...600).include?(status)
            [status, headers, [response.to_s]]
          end
        end

        private

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