PG_DB_URL_REGEXP = %r{\A(?:postgres://(?:([^:]+):)?(?:([^@]+)@)?([^/]+)/)?(.+)\Z}.freeze

namespace :db do
  task :migrate do
    path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'db', 'migrations'))
    system("bundle exec sequel -m #{path} #{ENV['DATABASE_URL']}")
  end

  task :create do
    exit 1 unless m = ENV['DATABASE_URL'].to_s.match(PG_DB_URL_REGEXP)
    opts = {
      :username => m[1],
      :host => m[3],
    }.inject([]) { |m, (k,v)| next m unless v; m << %(--#{k}="#{v}"); m }.join(" ")
    dbname = m[4]

    system("createdb #{opts} #{dbname}")
  end

  task :drop do
    exit 1 unless m = ENV['DATABASE_URL'].to_s.match(PG_DB_URL_REGEXP)
    opts = {
      :username => m[1],
      :host => m[3],
    }.inject([]) { |m, (k,v)| next m unless v; m << %(--#{k}="#{v}"); m }.join(" ")
    dbname = m[4]

    system("dropdb #{opts} #{dbname}")
  end

  task :setup => [:create, :migrate] do
  end

  task :reset => [:drop, :setup] do
  end
end
