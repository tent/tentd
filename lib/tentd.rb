require 'tentd/version'
require 'sequel'
require 'logger'

module TentD
  autoload :Model, 'tentd/model'

  TENT_VERSION = '0.3'.freeze

  def self.new(options = {})
    if database_url = options[:database] || ENV['DATABASE_URL']
      self.database_url = database_url
    end
  end

  def self.database
    @database || begin
      return unless database_url = ENV['DATABASE_URL']
      self.database_url = database_url
      @database
    end
  end

  def self.database_url=(database_url)
    @database = Sequel.connect(database_url, :logger => Logger.new(ENV['DB_LOGFILE'] || STDOUT))
  end

end
