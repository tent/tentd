$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'rack/test'
require 'tent-server'

Dir["#{File.dirname(__FILE__)}/support/*.rb"].each { |f| require f }

require 'data_mapper'
DataMapper.setup(:default, 'postgres://root@localhost/tent_server_test')

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.include JsonPostHelper
end
