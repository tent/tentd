module TentD
  module Model

    class Attachment < Sequel::Model(TentD.database[:attachments])
      def self.find_by_digest(digest)
        where(:digest => digest).first
      end

      def self.find_or_create(attrs)
        if attrs[:data].respond_to?(:read)
          data = attrs[:data].read
          attrs[:data].rewind if attrs[:data].respond_to?(:rewind)
          attrs[:data] = data
        end

        create(attrs)
      rescue Sequel::UniqueConstraintViolation => e
        if e.message =~ /duplicate key.*unique_attachments/
          first(:digest => attrs[:digest], :size => attrs[:size])
        else
          raise
        end
      end

      def data
        self[:data].lit
      end

      def each(&block)
        data.lit.each(&block)
      end
    end

  end
end
