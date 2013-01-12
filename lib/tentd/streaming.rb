module TentD
  module Streaming
    POSTGRES_CHANNEL = 'tent-post-created'.freeze

    def self.deliver_post(post_id)
      TentD::Model::Post.db.notify(POSTGRES_CHANNEL, payload: post_id.to_s)
    end
  end
end