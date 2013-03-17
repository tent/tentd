namespace :db do
  task :migrate do
    path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'db', 'migrations'))
    %x{bundle exec sequel -m #{path} #{ENV['DATABASE_URL']}}
  end
end
