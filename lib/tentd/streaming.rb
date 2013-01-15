require 'thread'
require 'tentd/streaming/backend_postgres'
require 'tentd/streaming/puma_fix'
require 'tentd/streaming/post_stream'

module TentD
  module Streaming
    LENGTH_PREFIXED_JSON_TYPE = 'application/vnd.tent.v0+length-prefixed-json-stream'.freeze
    
    def self.deliver_post(post_id)
      Backend.notify_post(post_id)
    end

    def self.requests_stream?(env)
      env['HTTP_ACCEPT'] == LENGTH_PREFIXED_JSON_TYPE
    end

    def self.connected_streams
      @connected_streams ||= []
    end

    def self.start_post_stream(env)
      user = TentD::Model::User.current
      stream = PostStream.new
      Backend.start_listener if !Backend.listener_running
      connected_streams << stream

      Thread.new do 
        TentD::Model::User.current = user
        begin
          stream.run(env)
        rescue Errno::EPIPE
        rescue Errno::ECONNRESET
          # client disconnected
        end
      end
    end
  end
end