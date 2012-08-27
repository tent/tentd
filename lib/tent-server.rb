require 'tent-server/version'
require 'tent-client'

module TentServer
  autoload :API, 'tent-server/api'
  autoload :Action, 'tent-server/action'
  autoload :Model, 'tent-server/model'
  autoload :JsonPatch, 'tent-server/json_patch'
end
