module TentD
  module Model

    class PostsAttachment < Sequel::Model(TentD.database[:posts_attachments])
    end

  end
end
