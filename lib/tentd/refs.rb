module TentD

  class Refs
    MAX_REFS_PER_POST = 5.freeze

    attr_reader :env
    def initialize(env)
      @env = env
      @proxy_clients = {}
    end

    def fetch(*posts, max_refs)
      fetch_with_proxy(*posts, max_refs)
    end

    def fetch_with_proxy(*posts, max_refs)
      max_refs = [MAX_REFS_PER_POST, max_refs.to_i].min
      return [] if max_refs == 0

      foreign_refs = []

      q = Query.new(Model::Post)

      q.query_conditions << "#{q.table_name}.user_id = ?"
      q.query_bindings << current_user.id

      ref_conditions = []
      posts.each do |post|
        next unless post.refs.to_a.any?

        post.refs.slice(0, max_refs).each do |ref|
          next if ref['entity'] && !can_read?(ref['entity'])

          if ref['entity'] && ref['entity'] != current_user.entity
            foreign_refs << ref
          end

          ref_conditions << ["AND",
            "#{q.table_name}.public_id = ?",
            ref['entity'].nil? ? "#{q.table_name}.entity_id = ?" : "#{q.table_name}.entity = ?"
          ]

          q.query_bindings << ref['post']
          q.query_bindings << (ref['entity'] || post.entity_id)
        end
      end
      return [] if ref_conditions.empty?
      q.query_conditions << ["OR"].concat(ref_conditions)

      unless proxy_condition == :always
        reffed_posts = q.all.uniq
      else
        reffed_posts = []
      end

      unless reffed_posts.size == max_refs
        foreign_refs = foreign_refs.inject([]) do |memo, ref|
          # skip over refs that are already found
          next if reffed_posts.any? { |post|
            if ref['version']
              post.entity == ref['entity'] && post.public_id == ref['post'] && post.version == ref['version']
            else
              post.entity == ref['entity'] && post.public_id == ref['post']
            end
          }

          fetch_via_proxy(ref) do |post|
            memo << post
          end

          memo
        end
      else
        foreign_refs = []
      end

      reffed_posts.map { |p| p.as_json(:env => env) } + foreign_refs
    end

    def fetch_via_proxy(ref, &block)
      return unless can_proxy?(ref['entity'])

      client = proxy_client(ref['entity'])

      params = {}
      params[:version] = ref['version'] if ref['version']

      res = client.post.get(ref['entity'], ref['post'], params)

      if res.status == 200 && (Hash === res.body) && (Hash === res.body['post'])
        yield Utils::Hash.symbolize_keys(res.body['post'])
      end
    rescue Faraday::Error::TimeoutError
    rescue Faraday::Error::ConnectionFailed
    end

    private

    def can_proxy?(entity)
      return false if entity == current_user.entity
      proxy_condition != :never && can_read?(entity)
    end

    def can_read?(entity)
      auth_candidate = Authorizer.new(env).auth_candidate
      auth_candidate && auth_candidate.read_entity?(entity)
    end

    def proxy_client(entity)
      @proxy_clients[entity] ||= if relationship = Model::Relationship.where(
        :user_id => current_user.id,
        :entity => entity,
      ).where(Sequel.~(:remote_credentials_id => nil)).first
        relationship.client
      else
        TentClient.new(entity)
      end
    end

    def proxy_condition
      case env['HTTP_CACHE_CONTROL']
      when 'no-cache'
        :always
      when 'proxy-if-miss'
        :on_miss
      else # 'only-if-cached' (default)
        :never
      end
    end

    def current_user
      @current_user ||= env['current_user']
    end

  end

end
