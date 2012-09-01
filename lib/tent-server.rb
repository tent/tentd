require 'tent-server/version'
require 'tent-client'

module TentServer
  autoload :API, 'tent-server/api'
  autoload :Action, 'tent-server/action'
  autoload :JsonPatch, 'tent-server/json_patch'
  autoload :TentVersion, 'tent-server/tent_version'

  def self.new(options={})
    DataMapper.setup(:default, options[:database] || ENV['DATABASE_URL'])
    API.new
  end
end

require 'tent-server/model'
