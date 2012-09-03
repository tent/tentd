require 'tentd/version'
require 'tent-client'

module TentD
  autoload :API, 'tentd/api'
  autoload :Action, 'tentd/action'
  autoload :JsonPatch, 'tentd/json_patch'
  autoload :TentVersion, 'tentd/tent_version'
  autoload :RackRequest, 'tentd/rack_request'

  def self.new(options={})
    if options[:database] || ENV['DATABASE_URL']
      DataMapper.setup(:default, options[:database] || ENV['DATABASE_URL'])
    end
    API.new
  end
end

require 'tentd/model'
