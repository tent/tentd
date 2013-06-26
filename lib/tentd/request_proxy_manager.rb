module TentD
  class RequestProxyManager
    def self.proxy_client(current_user, entity, options = {})
      if relationship = Model::Relationship.where(
        :user_id => current_user.id,
        :entity => entity,
      ).where(Sequel.~(:remote_credentials_id => nil)).first
        relationship.client(options)
      else
        TentClient.new(entity, options)
      end
    end

    attr_reader :env
    def initialize(env)
      @env = env
      @proxy_clients = {}
    end

    def get_post(entity, id, version = nil, &block)
      return unless can_proxy?(entity)

      client = proxy_client(entity)

      params = {}
      params[:version] = version if version

      res = client.post.get(entity, id, params)

      if res.status == 200 && (Hash === res.body) && (Hash === res.body['post'])
        yield Utils::Hash.symbolize_keys(res.body['post'])
      end

      res
    rescue Faraday::Error::TimeoutError
    rescue Faraday::Error::ConnectionFailed
    end

    def can_proxy?(entity)
      return false if entity == current_user.entity
      proxy_condition != :never && can_read?(entity)
    end

    def can_read?(entity)
      auth_candidate = Authorizer.new(env).auth_candidate
      auth_candidate && auth_candidate.read_entity?(entity)
    end

    def proxy_client(entity, options = nil)
      if options == {:skip_response_serialization => true}
        self.class.proxy_client(current_user, entity, options)
      elsif options
        self.class.proxy_client(current_user, entity, options)
      else
        self.class.proxy_client(current_user, entity)
      end
    end

    def proxy_condition
      return :never unless authorizer.proxy_authorized?

      case env['HTTP_CACHE_CONTROL']
      when 'no-cache'
        :always
      when 'proxy-if-miss'
        :on_miss
      when 'only-if-cached'
        :never
      else
        env['request.feed'] ? :never : :on_miss
      end
    end

    def authorizer
      @authorizer ||= Authorizer.new(env)
    end

    def current_user
      @current_user ||= env['current_user']
    end
  end
end
