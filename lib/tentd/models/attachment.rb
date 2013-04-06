module TentD
  module Model

    class Attachment < Sequel::Model(TentD.database[:attachments])
      def self.find_or_create(attrs)
        create(attrs)
      rescue Sequel::UniqueConstraintViolation => e
        if e.message =~ /duplicate key.*unique_attachments/
          first(:digest => attrs[:digest] || attrs['digest'], :size => attrs[:size] || attrs['size'])
        else
          raise
        end
      end
    end

  end
end
