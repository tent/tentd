require 'sequel-json'
require 'sequel-pg_array'

module TentD
  module Model

    NoDatabaseError = Class.new(StandardError)
    unless TentD.database
      raise NoDatabaseError.new("You need to set ENV['DATABASE_URL'] or pass database_url option to TentD.setup!")
    end

    require 'tentd/models/type'
    require 'tentd/models/entity'
    require 'tentd/models/user'
    require 'tentd/models/parent'
    require 'tentd/models/post'
    require 'tentd/models/post_builder'
    require 'tentd/models/app'
    require 'tentd/models/app_auth'
    require 'tentd/models/attachment'
    require 'tentd/models/posts_attachment'
    require 'tentd/models/relationship'
    require 'tentd/models/subscription'
    require 'tentd/models/credentials'
    require 'tentd/models/mention'

  end
end
