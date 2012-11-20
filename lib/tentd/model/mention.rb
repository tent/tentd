module TentD
  module Model
    class Mention < Sequel::Model(:mentions)
      many_to_one :post
      many_to_one :post_version # TODO: should to many to many

      def validate
        super
        errors.add(:post_id, 'post_id must not be blank') if post_id.nil? && post_version_id.nil?
        errors.add(:post_version_id, 'post_version_id must not be blank') if post_id.nil? && post_version_id.nil?
      end
    end
  end
end
