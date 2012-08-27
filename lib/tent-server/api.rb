module TentServer
  class API
    PER_PAGE = 50
    MAX_PER_PAGE = 200
    autoload :Posts, 'tent-server/api/posts'
    autoload :Groups, 'tent-server/api/groups'
    autoload :Profile, 'tent-server/api/profile'
    autoload :Router, 'tent-server/api/router'
    autoload :Middleware, 'tent-server/api/middleware'
    include Router

    mount Posts
    mount Groups
    mount Profile
    mount Followers
  end
end
