require 'tentd/version'
require 'sequel'
require 'logger'

module TentD

  TENT_VERSION = '0.3'.freeze

  def self.setup!(options = {})
    if database_url = options[:database] || ENV['DATABASE_URL']
      @database = Sequel.connect(database_url, :logger => Logger.new(ENV['DB_LOGFILE'] || STDOUT))
    end

    require 'tentd/model'
  end

  def self.database
    @database
  end

end
