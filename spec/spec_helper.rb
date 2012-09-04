$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'mocha_standalone'
require 'rack/test'
require 'tentd'
require 'fabrication'

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

require 'data_mapper'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include JsonRequest
  config.mock_with :mocha
  config.before(:suite) do
    # DataMapper::Logger.new(STDOUT, :debug)
    DataMapper.setup(:default, ENV['TEST_DATABASE_URL'] || 'postgres://localhost/tent_server_test')
    DataMapper.auto_migrate!
  end
end
