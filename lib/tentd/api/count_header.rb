module TentD
  class API
    class CountHeader < Middleware
      def action(env)
        count_env = env.dup
        count_env.params.return_count = true
        count = get_count(count_env)

        env['response.headers'] ||= {}
        env['response.headers']['Count'] = count

        env
      end

      def get_count(env)
      end
    end
  end
end
