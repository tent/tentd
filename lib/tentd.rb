require 'tentd/version'
require 'tent-client'

module TentD
  autoload :API, 'tentd/api'
  autoload :Action, 'tentd/action'
  autoload :JsonPatch, 'tentd/json_patch'
  autoload :TentVersion, 'tentd/tent_version'
  autoload :TentType, 'tentd/tent_type'
  autoload :RackRequest, 'tentd/rack_request'
  autoload :Notifications, 'tentd/notifications'

  def self.new(options={})
    if options[:database] || ENV['DATABASE_URL']
      DataMapper.setup(:default, options[:database] || ENV['DATABASE_URL'])
    end
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

require 'tentd/model'
