module TentD
  module Model

    class Attachment < Sequel::Model(TentD.database[:attachments])
    end

  end
end
