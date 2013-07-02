require 'tentd/models/large_object'

module TentD
  module Model

    class Attachment < Sequel::Model(TentD.database[:attachments])
      include SequelPGLargeObject

      pg_large_object :data

      def self.find_by_digest(digest)
        where(:digest => digest).first
      end

      def self.find_or_create(attrs)
        if String === attrs[:data]
          attrs[:data] = StringIO.new(attrs[:data])
        end

        create(attrs)
      rescue Sequel::UniqueConstraintViolation => e
        if e.message =~ /duplicate key.*unique_attachments/
          first(:digest => attrs[:digest], :size => attrs[:size])
        else
          raise
        end
      end

      def each(&block)
        return unless self.data
        self.data.each(&block)
      end

      def read
        return unless self.data
        self.data.read
      end
    end

  end
end
