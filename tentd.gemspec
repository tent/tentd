# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tentd/version'

Gem::Specification.new do |gem|
  gem.name          = "tentd"
  gem.version       = TentD::VERSION
  gem.authors       = ["Jonathan Rudenberg", "Jesse Stuart"]
  gem.email         = ["jonathan@titanous.com", "jessestuart@gmail.com"]
  gem.description   = %q{Tent Protocol server reference implementation}
  gem.summary       = %q{Tent Protocol server reference implementation}
  gem.homepage      = "http://tent.io"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'rack-mount', '~> 0.8.3'
  gem.add_runtime_dependency 'hashie'
  gem.add_runtime_dependency 'tent-client'
  gem.add_runtime_dependency 'json'
  gem.add_runtime_dependency 'yajl-ruby'
  gem.add_runtime_dependency 'pg'
  gem.add_runtime_dependency 'sequel'

  gem.add_development_dependency 'rack-test', '~> 0.6.1'
  gem.add_development_dependency 'rspec', '~> 2.11'
  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'guard-rspec'
  gem.add_development_dependency 'mocha', '0.12.6'
  gem.add_development_dependency 'fabrication', '2.3.0'
  gem.add_development_dependency 'faker'
end
