module TentD
  class API
    PER_PAGE = 50
    MAX_PER_PAGE = 200
    MEDIA_TYPE = 'application/vnd.tent.v0+json'.freeze
    PROFILE_REL = 'https://tent.io/rels/profile'.freeze

    autoload :Apps, 'tentd/api/apps'
    autoload :Posts, 'tentd/api/posts'
    autoload :Groups, 'tentd/api/groups'
    autoload :Profile, 'tentd/api/profile'
    autoload :Followers, 'tentd/api/followers'
    autoload :Followings, 'tentd/api/followings'
    autoload :CoreProfileData, 'tentd/api/core_profile_data'
    autoload :UserLookup, 'tentd/api/user_lookup'
    autoload :AuthenticationLookup, 'tentd/api/authentication_lookup'
    autoload :AuthenticationVerification, 'tentd/api/authentication_verification'
    autoload :AuthenticationFinalize, 'tentd/api/authentication_finalize'
    autoload :Authorization, 'tentd/api/authorization'
    autoload :Authorizable, 'tentd/api/authorizable'
    autoload :Router, 'tentd/api/router'
    autoload :Middleware, 'tentd/api/middleware'
    autoload :PaginationHeader, 'tentd/api/pagination_header'
    autoload :CountHeader, 'tentd/api/count_header'
    autoload :Serializer, 'tentd/api/serializer'
    include Router

    mount Apps
    mount Posts
    mount Groups
    mount Profile
    mount Followers
    mount Followings

    class HelloWorld < Middleware
      def action(env)
        [200, { 'Link' => %(<%s>; rel="%s") % [File.join(env['SCRIPT_NAME'], 'profile'), PROFILE_REL], 'Content-Type' => 'text/plain' }, ['Tent!']]
      end
    end

    class CorsPreflight < Middleware
      def action(env)
        headers = {
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => 'GET, POST, HEAD, PUT, DELETE, PATCH, OPTIONS',
          'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
          'Access-Control-Expose-Headers' => 'Count, Link',
          'Access-Control-Max-Age' => '2592000' # 30 days
        }
        [200, headers, []]
      end
    end

    get '/' do |b|
      b.use HelloWorld
    end

    options %r{/.*} do |b|
      b.use CorsPreflight
    end
  end
end
