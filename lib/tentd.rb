require 'tentd/version'
require 'tentd/utils'
require 'tent-client'

module TentD

  TENT_VERSION = '0.3'.freeze

  def self.setup!(options = {})
    require 'sequel'
    require 'logger'

    if database_url = options[:database_url] || ENV['DATABASE_URL']
      @database = Sequel.connect(database_url, :logger => Logger.new(ENV['DB_LOGFILE'] || STDOUT))
    end

    require 'tentd/model'
    require 'tentd/api'
  end

  def self.database
    @database
  end

end
