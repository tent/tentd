module TentServer
  class API
    PER_PAGE = 50
    MAX_PER_PAGE = 200
    autoload :Posts, 'tent-server/api/posts'
    autoload :Groups, 'tent-server/api/groups'
    autoload :Profile, 'tent-server/api/profile'
    autoload :Followers, 'tent-server/api/followers'
    autoload :Followings, 'tent-server/api/followings'
    autoload :AuthenticationLookup, 'tent-server/api/authentication_lookup'
    autoload :AuthenticationVerification, 'tent-server/api/authentication_verification'
    autoload :AuthenticationFinalize, 'tent-server/api/authentication_finalize'
    autoload :Router, 'tent-server/api/router'
    autoload :Middleware, 'tent-server/api/middleware'
    include Router

    mount Posts
    mount Groups
    mount Profile
    mount Followers
  end
end
