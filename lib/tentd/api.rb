require 'rack-putty'

module TentD
  class API

    require 'tentd/api/serialize_response'

    include Rack::Putty::Router

    stack_base SerializeResponse

  end
end
