module TentD
  module Model
    class Mention < Sequel::Model(:mentions)
      many_to_one :post
      many_to_many :post_versions, :class => PostVersion, :join_table => :post_versions_mentions, :left_key => :mention_id, :right_key => :post_version_id
    end
  end
end
