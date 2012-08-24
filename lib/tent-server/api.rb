require 'grape'

module TentServer
  class API < Grape::API
    autoload :Posts, 'tent-server/api/posts'

    mount Posts
  end
end
