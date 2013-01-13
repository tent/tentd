require 'thread'

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
  module Streaming
    LENGTH_PREFIXED_JSON_TYPE = 'application/vnd.tent.v0+length-prefixed-json-stream'.freeze
    POSTGRES_CHANNEL = 'tent-post-created'.freeze

    def self.deliver_post(post_id)
      TentD::Model::Post.db.notify(POSTGRES_CHANNEL, payload: post_id.to_s)
    end

    def self.requests_stream?(env)
      env['HTTP_ACCEPT'] == LENGTH_PREFIXED_JSON_TYPE
    end

    def self.start_post_stream(env)
      user = TentD::Model::User.current
      stream = PostStream.new
      listener.connected_streams << stream
          
      Thread.new do 
        TentD::Model::User.current = user
        begin
          stream.run(env)
        rescue Errno::EPIPE
          # client disconnected
        end
      end
    end

    def self.listener
      @listener ||= begin
        DatabaseListener.new.tap do |l|
          Thread.new do
            l.run
          end
        end
      end
    end

    class DatabaseListener
      attr_reader :connected_streams

      def initialize
        @connected_streams = []
      end

      def run
        db = Sequel.connect(ENV['DATABASE_URL'], :logger => Logger.new(STDOUT))
        db.listen(TentD::Streaming::POSTGRES_CHANNEL, loop: true) do |channel, backend, payload|
          @connected_streams.each do |s|
            s.queue << payload
          end
        end
      end
    end

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