lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler/setup'

if !ENV['RUN_SIDEKIQ'].nil?
  # run sidekiq server
  require 'tentd/worker'
  sidekiq_pid = TentD::Worker.run_server

  puts "Sidekiq server running (pid: #{sidekiq_pid})"
else
  sidekiq_pid = nil
end

require 'tentd'

TentD.setup!

TentD::Worker.configure_client

map (ENV['TENT_SUBDIR'] || '') + '/' do
  run TentD::API.new
end

if sidekiq_pid
  at_exit do
    puts "Killing sidekiq server (pid: #{sidekiq_pid})..."
    Process.kill("INT", sidekiq_pid)
  end
end
