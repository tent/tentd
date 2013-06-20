require 'tentd/version'
require 'tentd/utils'
require 'tent-client'

module TentD

  TENT_VERSION = '0.3'.freeze

  TentType = TentClient::TentType

  module REGEX
    VALID_ID = /\A[-0-9a-z_]+\Z/i
  end

  def self.setup!(options = {})
    setup_database!(options)

    require 'tentd/worker'
    require 'tentd/query'
    require 'tentd/feed'
    require 'tentd/refs'
    require 'tentd/authorizer'
    require 'tentd/request_proxy_manager'
    require 'tentd/api'
  end

  def self.setup_database!(options = {})
    require 'sequel'
    require 'logger'

    if database_url = options[:database_url] || ENV['DATABASE_URL']
      @database = Sequel.connect(database_url, :logger => Logger.new(ENV['DB_LOGFILE'] || STDOUT))
    end

    require 'tentd/model'

    Model.soft_delete = ENV['SOFT_DELETE'].to_s != 'false'
  end

  def self.database
    @database
  end

end
