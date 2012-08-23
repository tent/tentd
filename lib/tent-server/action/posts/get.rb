module Tent
  module Server
    module Action
      class Posts
        class Get
          def initialize(app, options={})
            @app, @options = app, options
          end

          def call(env)
            env['tent.post'] = ::Tent::Server::Post.find(env['post_id'])
            @app.call(env)
          end
        end
      end
    end
  end
end
