module TentServer
  class API
    PER_PAGE = 50
    MAX_PER_PAGE = 200
    autoload :Posts, 'tent-server/api/posts'
    autoload :Router, 'tent-server/api/router'
    autoload :Middleware, 'tent-server/api/middleware'
    include Router

    mount Posts
  end
end
