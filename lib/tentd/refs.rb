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
        # mixture of Model::Post and TentD::ProxiedPost
        next unless post.refs.to_a.any?

        post.refs.slice(0, max_refs).each do |ref|
          next if ref['entity'] && !can_read?(ref['entity'])

          if ref['entity'] && ref['entity'] != current_user.entity
            foreign_refs << ref
          end

          ref_conditions << ["AND",
            "#{q.table_name}.public_id = ?",
            (ref['entity'] || !post.entity_id) ? "#{q.table_name}.entity = ?" : "#{q.table_name}.entity_id = ?"
          ]

          q.query_bindings << ref['post']
          q.query_bindings << (ref['entity'] || post.entity_id || post.entity)
        end
      end
      return [] if ref_conditions.empty?
      q.query_conditions << ["OR"].concat(ref_conditions)

      unless request_proxy_manager.proxy_condition == :always
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

          request_proxy_manager.get_post(ref['entity'], ref['post'], ref['version']) do |post|
            memo << post
          end

          memo
        end
      else
        foreign_refs = []
      end

      reffed_posts.map { |p| p.as_json(:env => env) } + foreign_refs
    end

    private

    def can_read?(entity)
      auth_candidate = Authorizer.new(env).auth_candidate
      auth_candidate && auth_candidate.read_entity?(entity)
    end

    def request_proxy_manager
      @request_proxy_manager ||= env['request_proxy_manager']
    end

    def current_user
      @current_user ||= env['current_user']
    end

  end

end
