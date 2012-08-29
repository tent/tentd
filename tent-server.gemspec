# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tent-server/version'

Gem::Specification.new do |gem|
  gem.name          = "tent-server"
  gem.version       = TentServer::VERSION
  gem.authors       = ["Jonathan Rudenberg", "Jesse Stuart"]
  gem.email         = ["jonathan@titanous.com", "jessestuart@gmail.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'rack-mount'
  gem.add_runtime_dependency 'hashie'
  gem.add_runtime_dependency 'data_mapper'
  gem.add_runtime_dependency 'dm-ar-finders'
  gem.add_runtime_dependency 'dm-constraints'
  gem.add_runtime_dependency 'tent-client'

  gem.add_development_dependency 'rack-test'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'fabrication'
end
