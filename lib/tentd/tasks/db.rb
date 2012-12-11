namespace :db do
  task :migrate do
    %x{bundle exec sequel -m #{File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))}/db/migrations #{ENV['DATABASE_URL']}}
  end
end
