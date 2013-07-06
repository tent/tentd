module TentD

  class Feed

    DEFAULT_PAGE_LIMIT = 25.freeze
    MAX_PAGE_LIMIT = 200.freeze

    require 'tentd/feed/pagination'

    attr_reader :env
    attr_accessor :check_beyond_limit, :beyond_limit_exists
    def initialize(env)
      @env = env
    end

    def build_params
      params = env['params']

      if params['entities']
        params['entities'] = params['entities'].split(',').uniq.select { |entity|
          authorizer.read_entity?(entity)
        }
      end

      params
    end

    def params
      @params ||= build_params
    end

    def current_user
      env['current_user']
    end

    def authorizer
      Authorizer.new(env)
    end

    def entities
      return unless params['entities']
    end

    def limit
      _limit = if params['limit']
        [params['limit'].to_i, MAX_PAGE_LIMIT].min
      else
        DEFAULT_PAGE_LIMIT
      end

      if params['max_refs'] && authorizer.app?
        _limit = [MAX_PAGE_LIMIT / [Refs::MAX_REFS_PER_POST, params['max_refs'].to_i].min, _limit].min
      end

      _limit
    end

    def build_query(params = send(:params))
      q = _build_query(params)

      if authorizer.app?
        read_types = authorizer.auth_candidate.read_types

        unless read_types == %w( all )
          read_types.map! { |uri| TentType.new(uri) }
          authorized_base_types = read_types.select { |t| !t.has_fragment? }
          authorized_base_type_ids = Model::Type.find_types(authorized_base_types).map(&:id)
          authorized_types_with_fragments = read_types.select { |t| t.has_fragment? }
          authorized_type_ids_with_fragments = Model::Type.find_types(authorized_types_with_fragments).map(&:id)

          _condition = ["OR", "#{q.table_name}.public = true"]

          if authorized_base_type_ids.any?
            _condition << "#{q.table_name}.type_base_id IN ?"
            q.query_bindings << authorized_base_type_ids
          end

          if authorized_type_ids_with_fragments.any?
            _condition << "#{q.table_name}.type_id IN ?"
            q.query_bindings << authorized_type_ids_with_fragments
          end

          q.query_conditions << _condition
        end
      else
        q.query_conditions << "#{q.table_name}.public = true"
      end

      q
    end

    def _build_query(params)
      q = Query.new(Model::Post)
      q.deleted_at_table_names = %w( posts )

      # TODO: handle sort columns/order better
      sort_columns = case params['sort_by']
      when 'published_at'
        ["#{q.table_name}.published_at DESC"]
      when 'version.published_at'
        ["#{q.table_name}.version_published_at DESC"]
      else
        ["#{q.table_name}.received_at DESC"]
      end
      q.sort_columns = sort_columns

      q.query_conditions << "#{q.table_name}.user_id = ?"
      q.query_bindings << env['current_user'].id

      timestamp_column = q.sort_columns.split(' ').first

      if params['since']
        since_timestamp, since_version = params['since'].split(' ')
        since_timestamp = since_timestamp.to_i

        q.reverse_sort = true

        if since_version
          q.query_conditions << ["OR",
            ["AND", "#{timestamp_column} >= ?", "#{q.table_name}.version > ?"],
            "#{timestamp_column} > ?"
          ]
          q.query_bindings << since_timestamp
          q.query_bindings << since_version
          q.query_bindings << since_timestamp

          sort_columns << "#{q.table_name}.version DESC"
          q.sort_columns = sort_columns
        else
          q.query_conditions << "#{timestamp_column} > ?"
          q.query_bindings << since_timestamp
        end
      end

      if params['until']
        until_timestamp, until_version = params['until'].split(' ')
        until_timestamp = until_timestamp.to_i

        if until_version
          q.query_conditions << ["OR",
            ["AND", "#{timestamp_column} >= ?", "#{q.table_name}.version > ?"],
            "#{timestamp_column} > ?"
          ]
          q.query_bindings << until_timestamp
          q.query_bindings << until_version
          q.query_bindings << until_timestamp

          sort_columns << "#{q.table_name}.version DESC"
          q.sort_columns = sort_columns
        else
          q.query_conditions << "#{timestamp_column} > ?"
          q.query_bindings << until_timestamp
        end
      end

      if params['before']
        before_timestamp, before_version = params['before'].split(' ')
        before_timestamp = before_timestamp.to_i

        if before_version
          q.query_conditions << ["OR",
            ["AND", "#{timestamp_column} <= ?", "#{q.table_name}.version < ?"],
            "#{timestamp_column} < ?"
          ]
          q.query_bindings << before_timestamp
          q.query_bindings << before_version
          q.query_bindings << before_timestamp

          sort_columns << "#{q.table_name}.version DESC"
          q.sort_columns = sort_columns
        else
          q.query_conditions << "#{timestamp_column} < ?"
          q.query_bindings << before_timestamp
        end
      end

      if params['types']
        tent_types = params['types'].to_s.split(",").uniq.map { |uri| TentType.new(uri) }
        tent_types_without_fragment = tent_types.select { |t| !t.has_fragment? }
        tent_types_with_fragment = tent_types.select { |t| t.has_fragment? }

        base_type_ids = Model::Type.where(:base => tent_types_without_fragment.map(&:base), :fragment => nil).map(&:id)
        full_type_ids = Model::Type.where(:base => tent_types_with_fragment.map(&:base), :fragment => tent_types_with_fragment.map { |t| t.fragment.to_s }).map(&:id)

        q.query_conditions << ["OR", "#{q.table_name}.type_base_id IN ?", "#{q.table_name}.type_id IN ?"]
        q.query_bindings << base_type_ids
        q.query_bindings << full_type_ids
      end

      if params['entities']
        q.query_conditions << "entity IN ?"
        q.query_bindings << params['entities']
      end

      if params['mentions']
        mentions_table = Model::Mention.table_name
        q.join("INNER JOIN #{mentions_table} ON #{mentions_table}.post_id = #{q.table_name}.id")

        mentions = Array(params['mentions']).map do |mentions_param|
          mentions_param.split(',').map do |mention|
            entity, post = mention.split(' ')
            mention = { :entity => entity }
            mention[:post] = post if post
            mention
          end
        end

        # fetch entity ids
        flat_mentions = mentions.flatten
        entities = flat_mentions.map { |mention| mention[:entity] }
        entities_q = Query.new(Model::Entity)
        entities_q.query_conditions << "entity IN ?"
        entities_q.query_bindings << entities
        _entity_mapping = {}
        entities_q.all.each do |entity|
          _entity_mapping[entity.entity] = entity.id
        end
        flat_mentions.each do |m|
          m[:entity_id] = _entity_mapping[m[:entity]]
        end

        mentions.each do |_mentions|
          mentions_bindings = []
          mentions_conditions = ['OR'].concat(_mentions.map { |mention|
            mentions_bindings << mention[:entity_id]
            if mention[:post]
              mentions_bindings << mention[:post]
              "(#{mentions_table}.entity_id = ? AND #{mentions_table}.post = ?)"
            else
              "#{mentions_table}.entity_id = ?"
            end
          })

          q.query_conditions << mentions_conditions
          q.query_bindings.push(*mentions_bindings)
        end
      end

      q.limit = limit

      unless params['since']
        q.limit += 1
        self.check_beyond_limit = true
      end

      q
    end

    def count
      build_query.count
    end

    def fetch_query
      _params = Utils::Hash.deep_dup(params)

      if _params['entities'] && request_proxy_manager.proxy_condition == :always
        # separate entities to be proxied
        _proxy_entities = _params['entities'] - [current_user.entity]
        _params['entities'] = _params['entities'] - _proxy_entities

        @models = merge_results(build_query(_params).all, fetch_via_proxy(_proxy_entities))
      else
        @models = build_query(_params).all
      end

      if check_beyond_limit
        if @models.size == limit + 1
          @models.pop
          self.beyond_limit_exists = true
        else
          self.beyond_limit_exists = false
        end
      end

      @models
    end

    def fetch_via_proxy(entities)
      posts = []
      entities.each do |entity|
        client = request_proxy_manager.proxy_client(entity)
        res = client.post.list(params.merge('entities' => entity))
        if res.status == 200
          posts.concat res.body['posts']
        end
      end
      posts.map { |post| ProxiedPost.new(post) }
    end

    def merge_results(models, proxied_posts)
      (models + proxied_posts).sort_by do |item|
        case params['sort_by']
        when 'published_at'
          item.published_at
        when 'version.published_at'
          item.version_published_at
        else
          item.received_at || item.published_at
        end
      end
    end

    def models
      @models || fetch_query
    end

    def as_json(options = {})
      _models = models
      res = {
        :pages => Pagination.new(self).as_json,
        :posts => _models.map { |m| m.as_json(:env => env) }
      }

      if params['max_refs'] && authorizer.app?
        res[:refs] = Refs.new(env).fetch(*_models, params['max_refs'].to_i)
      end

      if params['profiles'] && authorizer.app?
        res[:profiles] = API::MetaProfile.new(env, _models).profiles(params['profiles'].split(','))
      end

      res
    end

    private

    def request_proxy_manager
      @request_proxy_manager ||= env['request_proxy_manager']
    end
  end

end
