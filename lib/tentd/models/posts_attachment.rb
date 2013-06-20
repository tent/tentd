module TentD
  module Model

    class PostsAttachment < Sequel::Model(TentD.database[:posts_attachments])
      plugin :paranoia if Model.soft_delete


      def self.create(attrs)
        super
      rescue Sequel::UniqueConstraintViolation => e
        if e.message =~ /duplicate key.*unique_posts_attachments/
          attrs = Utils::Hash.symbolize_keys(attrs)
          first(:post_id => attrs[:post_id], :attachment_id => attrs[:attachment_id], :content_type => attrs[:content_type])
        else
          raise
        end
      end
    end

  end
end
