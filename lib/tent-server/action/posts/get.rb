module TentServer
  module Action
    class Posts
      class Get
        def initialize(app, options={})
          @app, @options = app, options
        end

        def call(env)
          env['tent.post'] = ::TentServer::Model::Post.get(env['post_id'])
          @app.call(env)
        end
      end
    end
  end
end
