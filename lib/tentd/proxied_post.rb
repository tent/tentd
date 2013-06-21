module TentD
  class ProxiedPost
    def initialize(post_json)
      @post_json = Utils::Hash.symbolize_keys(post_json, :deep => false)
      @post_json[:version] = Utils::Hash.symbolize_keys(@post_json[:version], :deep => false)
    end

    def public_id
      @post_json[:id]
    end

    def entity
      @post_json[:entity]
    end

    def entity_id
      @entity_id ||= begin
        _entity = Model::Entity.select(:id).where(:entity => entity).first
        _entity.id if _entity
      end
    end

    def content
      @post_json[:content]
    end

    def version
      @post_json[:version][:id]
    end

    def version_parents
      @post_json[:version][:parents]
    end

    def published_at
      @post_json[:published_at]
    end

    def received_at
      @post_json[:received_at]
    end

    def version_published_at
      @post_json[:version][:published_at]
    end

    def refs
      @post_json[:refs]
    end

    def mentions
      @post_json[:mentions]
    end

    def attachments
      @post_json[:attachments]
    end

    def as_json(options = {})
      @post_json
    end
  end
end
