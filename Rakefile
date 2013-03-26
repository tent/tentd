require 'bundler/setup'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:rspec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
end

task :validator_spec do
  # get random port
  require 'socket'
  tmp_socket = Socket.new(:INET, :STREAM)
  tmp_socket.bind(Addrinfo.tcp("127.0.0.1", 0))
  host, port = tmp_socket.local_address.getnameinfo
  tmp_socket.close

  def puts_error(e)
    print "#{e.inspect}:\n\t"
    puts e.backtrace.slice(0, 20).join("\n\t")
  end

  tentd_pid = fork do
    require 'puma/cli'

    stdout, stderr = StringIO.new, STDERR

    # don't show database activity
    ENV['DB_LOGFILE'] ||= '/dev/null'

    # use test database
    ENV['DATABASE_URL'] = ENV['TEST_DATABASE_URL']

    puts "Booting Tent server on port #{port}..."

    rackup_path = File.expand_path(File.join(File.dirname(__FILE__), 'config.ru'))
    cli = Puma::CLI.new ['--port', port.to_s, rackup_path], stdout, stderr
    begin
    cli.run
    rescue => e
      puts_error(e)
      exit 1
    end
  end

  validator_pid = fork do
    at_exit do
      puts "Stopping Tent server (PID: #{tentd_pid})..."
      Process.kill("INT", tentd_pid)
    end

    # wait until tentd server boots
    tentd_started = false
    until tentd_started
      begin
        Socket.tcp("127.0.0.1", port) do |connection|
          tentd_started = true
          connection.close
        end
      rescue Errno::ECONNREFUSED
      end
    end

    begin
      require 'tent-validator'
      TentValidator.remote_server = "http://#{host}:#{port}"
      TentValidator::Runner::CLI.run
    rescue => e
      puts_error(e)
      exit 1
    end
  end

  # wait for tentd process to exit
  Process.waitpid(tentd_pid)

  # kill validator if tentd exits first
  puts "Stopping Validator (PID: #{validator_pid})..."
  Process.kill("INT", validator_pid)
end

task :spec => [:rspec, :validator_spec] do
end
task :default => :spec

lib = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tentd/tasks/db'
