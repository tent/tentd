module TentD
  class API

    class PostsFeed < Middleware
      def action(env)
        env['request.feed'] = true

        feed = Feed.new(env)

        env['response'] = feed

        if env['REQUEST_METHOD'] == 'HEAD'
          env['response.headers'] ||= {}
          env['response.headers']['Count'] = feed.count.to_s
        end

        env
      end
    end

  end
end
