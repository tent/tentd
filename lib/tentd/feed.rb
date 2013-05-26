module TentD

  class Feed

    require 'tentd/feed/query'

    attr_reader :env
    def initialize(env)
      @env = env
    end

    def params
      env['params']
    end

    def query
      q = Query.new(Model::Post)
      q.sort_columns = :received_at
      q.sort_order = 'DESC'

      if params['types']
        requested_types = params['types'].map { |uri| TentType.new(uri) }

        # TODO: refactor to only need query
        type_ids = Model::Type.where(:base => requested_types.map(&:base)).all.select { |type|
          requested_types.any? { |t| t.base == type.base && t.fragment == type.fragment }
        }.map(&:id)

        q.query_conditions << "type_id IN ?"
        q.query_bindings << type_ids
      end

      q
    end

    def fetch_query
      query.all
    end

    def as_json(options = {})
      models = fetch_query
      {
        :pages => {},
        :posts => models.map(&:as_json)
      }
    end
  end

end
