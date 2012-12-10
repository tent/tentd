module TentD
  class API
    class PaginationHeader < Middleware
      def action(env)
        return env unless env.response.kind_of?(Array) && env.response.size > 0

        env['response.headers'] ||= {}
        pagination = [%(<#{prev_uri(env)}>; rel="prev"), %(<#{next_uri(env)}>; rel="next")]
        if env['response.headers']['Link']
          env['response.headers']['Link'] += ", #{pagination.join(', ')}"
        else
          env['response.headers']['Link'] = pagination.join(', ')
        end

        env
      end

      private

      def next_uri(env)
        uri = self_uri(env)
        uri.path = env['SCRIPT_NAME']

        uri.query = serialize_params(build_next_params(env))
        uri
      end

      def build_next_params(env)
        params = clone_params(env)
        resource = env.response.last

        params[next_id_key(env)] = resource.public_id
        params
      end

      def next_id_key(env)
        if env.params.order.to_s.downcase == 'asc'
          :since_id
        else
          :before_id
        end
      end

      def prev_uri(env)
        uri = self_uri(env)
        uri.path = env['SCRIPT_NAME']

        uri.query = serialize_params(build_prev_params(env))
        uri
      end

      def build_prev_params(env)
        params = clone_params(env)
        resource = env.response.first

        params[prev_id_key(env)] = resource.public_id
        params
      end

      def prev_id_key(env)
        if env.params.order.to_s.downcase == 'asc'
          :before_id
        else
          :since_id
        end
      end

      def clone_params(env)
        params = env.params.dup
        params.delete(:captures)
        params.delete(:before_id)
        params.delete(:since_id)
        params
      end
    end
  end
end
