module TentD

  class Feed
    def initialize
    end

    def fetch_query
      Model::Post.order(Sequel.desc(:published_at)).all
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
