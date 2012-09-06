$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'mocha_standalone'
require 'rack/test'
require 'tentd'
require 'fabrication'
require 'tentd/core_ext/hash/slice'
require 'girl_friday'

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

ENV['RACK_ENV'] ||= 'test'

require 'data_mapper'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include JsonRequest
  config.mock_with :mocha
  config.before(:suite) do
    GirlFriday::WorkQueue.immediate!
    # DataMapper::Logger.new(STDOUT, :debug)
    DataMapper.setup(:default, ENV['TEST_DATABASE_URL'] || 'postgres://localhost/tent_server_test')
    DataMapper.auto_migrate!
  end
end
