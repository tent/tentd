module TentD

  class Feed
    attr_reader :env
    def initialize(env)
      @env = env
    end

    def params
      env['params']
    end

    def query
      q = Model::Post.order(Sequel.desc(:published_at))

      if params['types']
        requested_types = params['types'].map { |uri| TentType.new(uri) }

        # TODO: refactor to only need query
        type_ids = Model::Type.where(:base => requested_types.map(&:base)).all.select { |type|
          requested_types.any? { |t| t.base == type.base && t.fragment == type.fragment }
        }.map(&:id)

        q = q.where(:type_id => type_ids)
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
