module TentD
  module Model
    class Mention < Sequel::Model(:mentions)
      many_to_one :post
      many_to_many :post_versions, :class => PostVersion, :join_table => :post_versions_mentions, :left_key => :mention_id, :right_key => :post_version_id

      def as_json(options = {})
        attrs = {
          :entity => entity,
          :post => mentioned_post_id,
        }
        if self[:type_base] && self[:type_version]
          type = TentType.new
          type.base = self[:type_base]
          type.version = self[:type_version]
          attrs[:type] = type.uri
        end
        attrs
      end
    end
  end
end
