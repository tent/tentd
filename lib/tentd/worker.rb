module TentD
  module Worker

    require 'sidekiq'

    def self.configure_client(redis_opts = {}, &block)
      Sidekiq.configure_client do |config|
        config.redis = { :namespace => ENV['REDIS_NAMESPACE'] || 'tentd.worker', :size => 1, :url => ENV['REDIS_URL'] }.merge(redis_opts)
        yield(config) if block_given?
      end
    end

    def self.configure_server(redis_opts = {}, &block)
      TentD.setup_database!
      Sidekiq.configure_server do |config|
        config.redis = { :namespace => ENV['REDIS_NAMESPACE'] || 'tentd.worker', :url => ENV['REDIS_URL'] }.merge(redis_opts)
        yield(config) if block_given?
      end
    end

    def self.run_server
      sidekiq_pid = fork do
        begin
          require 'sidekiq/cli'
          require 'tentd'

          STDOUT.reopen(ENV['SIDEKIQ_LOG'] || STDOUT)
          STDERR.reopen(ENV['SIDEKIQ_LOG'] || STDERR)

          Sidekiq.options[:require] = File.join(File.expand_path(File.dirname(__FILE__)), 'sidekiq.rb') # tentd/sidekiq
          Sidekiq.options[:logfile] = ENV['SIDEKIQ_LOG']

          TentD::Worker.configure_server

          cli = Sidekiq::CLI.instance
          cli.parse([])
          cli.run
        rescue => e
          raise e if $DEBUG
          STDERR.puts e.message
          STDERR.puts e.backtrace.join("\n")
          exit 1
        end
      end
      sidekiq_pid
    end

    require 'tentd/worker/relationship_initiation'
    require 'tentd/worker/notification_dispatch'
    require 'tentd/worker/notification_app_deliverer'
    require 'tentd/worker/notification_deliverer'

  end
end
