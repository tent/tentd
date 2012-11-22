require 'bundler/setup'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
end
task :default => :spec

namespace :db do
  task :migrate do
    %x{bundle exec sequel -m ./db/migrations #{ENV['DATABASE_URL']}}
  end
end
