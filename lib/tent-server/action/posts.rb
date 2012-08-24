module TentServer
  module Action
    class Posts
      autoload :Get, 'tent-server/action/posts/get'

      def self.get(env)
        Builder.new.tap do |b|
          b.use Get
          b.use Serialize
        end.call env
      end
    end
  end
end
