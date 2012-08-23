module Tent
  module Server
    module Action
      class << self
        def get_post(env)
          Builder.new.tap do |b|
            b.use Persistence::Post :get
          end.call env
        end
      end
    end
  end
end
