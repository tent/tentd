module TentD
  class API

    class MetaProfile

      SPECIFIERS = %w( entity mentions refs parents permissions ).freeze

      def self.meta_type_id
        @meta_type_id ||= Model::Type.find_or_create_full("https://tent.io/types/meta/v0#").id
      end

      def self.profile_as_json(post)
        return unless Hash === post.content['profile']
        data = Utils::Hash.deep_dup(post.content['profile'])
        data['avatar_digest'] = post.attachments.first['digest'] if post.attachments.to_a.any?
        data
      end

      attr_reader :env, :posts
      def initialize(env, posts)
        @env, @posts = env, posts
      end

      def profiles(specifiers)
        _entities = entities(specifiers)
        _entity_ids = entity_ids(_entities)

        return {} unless _entities.any?

        unless request_proxy_manager.proxy_condition == :always
          models = Model::Post.where(
            :user_id => current_user_id,
            :type_id => meta_type_id,
            :entity_id => _entity_ids
          ).order(:public_id, Sequel.desc(:version_received_at)).distinct(:public_id).all.to_a

          _entities -= models.map(&:entity)
        else
          models = []
        end

        unless request_proxy_manager.proxy_condition == :never
          _meta_profiles = _entities.inject({}) do |memo, entity|
            fetch_meta_profile(entity) do |meta_profile|
              memo[entity] = meta_profile
            end

            memo
          end
        else
          _meta_profiles = {}
        end

        models.inject(_meta_profiles) { |memo, post|
          memo[post.entity] = profile_as_json(post)
          memo
        }
      end

      def profile_as_json(post)
        self.class.profile_as_json(post)
      end

      private

      def authorizer
        @authorizer ||= Authorizer.new(env)
      end

      def fetch_meta_profile(entity, &block)
        return unless meta_post = TentClient.new(entity).server_meta_post
        return unless meta_profile = meta_post['content']['profile']

        if meta_post['attachments'].to_a.any?
          meta_profile['avatar_digest'] = meta_post['attachments'][0]['digest']
        end

        yield meta_profile
      end

      def current_user_id
        @current_user_id = env['current_user'].id
      end

      def request_proxy_manager
        @request_proxy_manager ||= env['request_proxy_manager']
      end

      def meta_type_id
        self.class.meta_type_id
      end

      def entity_ids(_entities)
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
          next memo unless authorizer.read_entity?(post.entity)

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
