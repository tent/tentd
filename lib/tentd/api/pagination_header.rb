module TentD
  class API
    class PaginationHeader < Middleware
      def action(env)
        return env unless env.response.kind_of?(Array) && env.response.size > 0

        env['response.headers'] ||= {}
        pagination = [%(<#{prev_uri(env).to_s}>; rel="prev"), %(<#{next_uri(env).to_s}>; rel="next")]
        if env['response.headers']['Link']
          env['response.headers']['Link'] += ",#{pagination.join(',')}"
        else
          env['response.headers']['Link'] = pagination.join(',')
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
        params = env.params.dup
        resource = env.response.last

        params.before_id = resource.public_id
        params
      end

      def prev_uri(env)
        uri = self_uri(env)
        uri.path = env['SCRIPT_NAME']

        uri.query = serialize_params(build_prev_params(env))
        uri
      end

      def build_prev_params(env)
        params = env.params.dup
        resource = env.response.first

        params.since_id = resource.public_id
        params
      end
    end
  end
end
