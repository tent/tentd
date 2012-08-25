require 'data_mapper'
require 'tent-server/data_mapper_array_property'

module TentServer
  module Model
    autoload :Post, 'tent-server/model/post'
    autoload :Follow, 'tent-server/model/follow'
  end
end
