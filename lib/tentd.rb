require 'tentd/version'
require 'tent-client'
require 'logger'
require 'sequel'

module TentD
  autoload :API, 'tentd/api'
  autoload :Action, 'tentd/action'
  autoload :JsonPatch, 'tentd/json_patch'
  autoload :TentVersion, 'tentd/tent_version'
  autoload :TentType, 'tentd/tent_type'
  autoload :Model, 'tentd/model'

  TENT_VERSION = '0.2'.freeze

  def self.new(options={})
    if database_url = options[:database] || ENV['DATABASE_URL']
      Sequel.connect(database_url, :logger => Logger.new(ENV['DB_LOGFILE'] || STDOUT))
    end

    require "tentd/notifications/#{options[:job_backend] || 'girl_friday'}"

    @faraday_adapter = options[:faraday_adapter]
    API.new
  end

  def self.faraday_adapter
    @faraday_adapter
  end

  def self.faraday_adapter=(a)
    @faraday_adapter = a
  end
end
