module Tent
  module Server
    module Action
      class << self
        def get_post(env)
          Builder.new.tap do |b|
            b.use GetPosts
          end.call env
        end
      end
    end
  end
end
