$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'rack/test'
require 'sp-server'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
