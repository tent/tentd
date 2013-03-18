require 'sequel-json'
require 'sequel-pg_array'

module TentD
  module Model

    NoDatabaseError = Class.new(StandardError)
    unless TentD.database
      raise NoDatabaseError.new("You need to set ENV['DATABASE_URL'] or TentD.database_url")
    end

    require 'tentd/models/type'
    require 'tentd/models/user'
    require 'tentd/models/post'
    require 'tentd/models/app'
    require 'tentd/models/attachment'

  end
end
