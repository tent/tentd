module Tent
  module Server
    module Action
      class Posts
        autoload :Get, 'tent-server/action/posts/get'

        def self.get(env)
          Builder.new.tap do |b|
            b.use Get
          end.call env
        end
      end
    end
  end
end
