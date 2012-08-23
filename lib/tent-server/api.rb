require 'grape'

module Tent
  module Server
    class API < Grape::API
      autoload :Posts, 'tent-server/api/posts'

      mount Posts
    end
  end
end
