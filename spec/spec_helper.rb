$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'mocha_standalone'
require 'rack/test'
require 'tent-server'
require 'fabrication'

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

require 'data_mapper'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include JsonRequest
  config.mock_with :mocha
  config.before(:all) do
    DataMapper.setup(:default, 'postgres://localhost/tent_server_test')
    DataMapper.auto_migrate!
  end
end
