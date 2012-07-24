# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sp-server/version'

Gem::Specification.new do |gem|
  gem.name          = "sp-server"
  gem.version       = SP::Server::VERSION
  gem.authors       = ["Jonathan Rudenberg"]
  gem.email         = ["jonathan@titanous.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency 'grape'

  gem.add_development_dependency 'rack-test'
  gem.add_development_dependency 'rspec', '~> 2.11'
  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake'
end
