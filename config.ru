lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'bundler/setup'

require 'tentd'

TentD.setup!

map (ENV['TENT_SUBDIR'] || '') + '/' do
  run TentD::API.new
end
