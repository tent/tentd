require 'rack-putty'

module TentD
  class API

    CONTENT_TYPE = %(application/vnd.tent.post.v0+json; rel="%s").freeze

    require 'tentd/api/serialize_response'
    require 'tentd/api/middleware'
    require 'tentd/api/user_lookup'
    require 'tentd/api/parse_input_data'
    require 'tentd/api/validate_input_data'

    include Rack::Putty::Router

    stack_base SerializeResponse

    middleware UserLookup
    middleware ParseInputData
    middleware ValidateInputData

    class CreatePost < Middleware
      def action(env)
        env['response'] = Model::Post.create_from_env(env)
        env
      end
    end

    post '/posts' do |b|
      b.use CreatePost
    end

  end
end
