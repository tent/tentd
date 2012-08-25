module TentServer
  class API
    autoload :Posts, 'tent-server/api/posts'
    autoload :Router, 'tent-server/api/router'
    autoload :Middleware, 'tent-server/api/middleware'
    include Router

    mount Posts
  end
end
