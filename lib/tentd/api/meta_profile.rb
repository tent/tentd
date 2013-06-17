module TentD
  class API

    class MetaProfile

      SPECIFIERS = %w( entity mentions refs parents permissions ).freeze

      def self.meta_type_id
        @meta_type_id ||= Model::Type.find_or_create_full("https://tent.io/types/meta/v0#").id
      end

      attr_reader :current_user_id, :posts
      def initialize(current_user_id, posts)
        @current_user_id, @posts = current_user_id, posts
      end

      def profiles(specifiers)
        _entity_ids = entity_ids(specifiers)
        return {} unless _entity_ids.any?

        Model::Post.where(
          :user_id => current_user_id,
          :type_id => meta_type_id,
          :entity_id => _entity_ids
        ).order(:public_id, Sequel.desc(:version_received_at)).distinct(:public_id).all.to_a.inject({}) { |memo, post|
          memo[post.entity] = post.content['profile']
          memo
        }
      end

      private

      def meta_type_id
        self.class.meta_type_id
      end

      def entity_ids(specifiers)
        _entities = entities(specifiers)
        return [] unless _entities.any?

        _entity_id_mapping = {}
        posts.each { |post| _entity_id_mapping[post.entity] = post.entity_id }

        _entity_ids = []
        _entities.each { |entity|
          if _id = _entity_id_mapping[entity]
            _entity_ids.push(_id)
          end
        }
        _entities -= _entity_id_mapping.keys
        return _entity_ids unless _entities.any?

        _entity_ids + Model::Entity.select(:id).where(:entity => _entities).all.to_a.map(&:id)
      end

      def entities(specifiers)
        return [] unless posts.any?

        specifiers = specifiers & SPECIFIERS
        return [] unless specifiers.any?

        posts.inject([]) do |memo, post|
          specifiers.each do |specifier|
            case specifier
            when 'entity'
              memo << post.entity
            when 'mentions'
              memo += post.mentions.to_a.map { |m| m['entity'] || post.entity }
            when 'refs'
              memo += post.refs.to_a.map { |r| r['entity'] || post.entity }
            when 'parents'
              memo += post.version_parents.to_a.map { |p| p['entity'] || post.entity }
            end
          end.uniq

          memo
        end
      end
    end

  end
end
