module TentD
  module Streaming
    module Backend # not BackendPostgres
      class << self
        attr_reader :listener_running
      end
      @listener_running = false
      POSTGRES_CHANNEL = 'tent-post-created'.freeze

      def self.notify_post(post_id)
        TentD::Model::Post.db.notify(POSTGRES_CHANNEL, payload: post_id.to_s)
      end

      def self.start_listener
        Thread.new do
          db = Sequel.connect(ENV['DATABASE_URL'], :logger => Logger.new(STDOUT))
          db.listen(POSTGRES_CHANNEL, loop: true) do |channel, backend, payload|
            TentD::Streaming.connected_streams.each do |s|
              s.queue << payload
            end
          end
        end
        @listener_running = true
      end
    end
  end
end