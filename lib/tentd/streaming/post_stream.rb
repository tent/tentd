module TentD
  module Streaming
    class PostStream < Struct.new(:env)
      include TentD::API::Authorizable
      attr_reader :queue

      def initialize
        @queue = Queue.new
      end

      def run(env)
        socket = env['puma.socket']
        auth = env.current_auth
        
        headers = { "Content-Type" => LENGTH_PREFIXED_JSON_TYPE }
        headers.merge env['response.headers'] || {}

        # Just a tad hackish
        socket.write "HTTP/1.1 200 OK\r\n"
        headers.each do |k,v|
          socket.write "#{k}: #{v}\r\n"
        end
        socket.write "\r\n"

        loop do
          post_id = @queue.pop

          if authorize_env?(env, :read_posts)
            q = Model::Post.where(:id => post_id)

            unless env.current_auth.post_types.include?('all')
              q = q.where(:type_base => auth.post_types.map { |t| TentType.new(t).base })
            end

            post = q.first
          else
            post = Model::Post.find_with_permissions(post_id, auth)
          end

          if post
            serialized = TentD::API::Serializer.serialize(post, env)
            socket.write "#{serialized.bytesize}\r\n"
            socket.write "#{serialized}\r\n"
          end
        end
      end
    end
  end
end