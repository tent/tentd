$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'mocha_standalone'
require 'rack/test'
require 'tent-server'
require 'fabrication'

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

require 'data_mapper'
DataMapper.setup(:default, 'postgres://root@localhost/tent_server_test')
DataMapper.auto_migrate!

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include JsonPostHelper
  config.mock_with :mocha
end
