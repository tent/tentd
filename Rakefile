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
    unless ENV['DATABASE_URL'] = ENV['TEST_DATABASE_URL']
      STDERR.puts "You must set TEST_DATABASE_URL!"
      exit 1
    end

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
      begin
        Process.kill("INT", tentd_pid)
      rescue Errno::ESRCH
      end
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
      rescue Interrupt
        exit
      end
    end

    # don't show database activity
    ENV['DB_LOGFILE'] ||= '/dev/null'

    begin
      require 'tent-validator'
      server_url = "http://#{host}:#{port}#{ENV['TENT_SUBDIR']}"
      TentValidator.setup!(
        :remote_entity_uri => server_url,
        :remote_server_meta => {
          "entity" => server_url,
          "previous_entities" => [],
          "servers" => [
            {
              "version" => "0.3",
              "urls" => {
                "app_auth_request" => "#{server_url}/oauth/authorize",
                "app_token_request" => "#{server_url}/oauth/token",
                "posts_feed" => "#{server_url}/posts",
                "new_post" => "#{server_url}/posts",
                "post" => "#{server_url}/posts/{entity}/{post}",
                "post_attachment" => "#{server_url}/posts/{entity}/{post}/attachments/{name}?version={version}",
                "batch" => "#{server_url}/batch",
                "server_info" => "#{server_url}/server"
              },
              "preference" => 0
            }
          ]
        },
        :tent_database_url => ENV['TEST_VALIDATOR_TEND_DATABASE_URL']
      )
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
  begin
    Process.kill("INT", validator_pid)
  rescue Errno::ESRCH
  end

  exit $?.exitstatus
end

task :spec => [:rspec, :validator_spec] do
end
task :default => :spec

lib = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tentd/tasks/db'
