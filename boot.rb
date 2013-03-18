lib = File.expand_path(File.join(File.dirname(__FILE__), 'lib'))
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'tentd'
