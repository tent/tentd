$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

ENV['RACK_ENV'] ||= 'test'

require 'bundler/setup'
require 'mocha/api'
require 'rack/test'

require 'tentd'

ENV['TENT_ENTITY'] ||= 'http://example.org'

ENV['DB_LOGFILE'] ||= '/dev/null'
TentD.setup!(:database_url => ENV['TEST_DATABASE_URL'])

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.mock_with :mocha
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around(:each) do |example|
    TentD.database.transaction(:rollback=>:always) { example.run }
  end
end
