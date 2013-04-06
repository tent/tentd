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
    require 'tentd/models/post'
    require 'tentd/models/app'
    require 'tentd/models/attachment'
    require 'tentd/models/posts_attachment'

  end
end
