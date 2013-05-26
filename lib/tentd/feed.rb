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

        type_ids_q = Query.new(Model::Type)
        type_ids_q.select_columns = :id

        requested_types.each do |type|
          type_ids_q.query_conditions << ["AND", "base = ?"]
          type_ids_q.query_bindings << type.base

          if type.has_fragment?
            if type.fragment.nil?
              type_ids_q.query_conditions.last << "fragment IS NULL"
            else
              type_ids_q.query_conditions.last << "fragment = ?"
              type_ids_q.query_bindings << type.fragment
            end
          end
        end

        type_ids = type_ids_q.all(:conditions_sep => 'OR').map(&:id)

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
