module TentD
  class API
    class CountHeader < Middleware
      def action(env)
        count_env = env.dup
        count_env.params.return_count = true
        status, headers, response = get_count(count_env)

        if (200...400).include?(status)
          env['response.headers'] ||= {}
          env['response.headers']['Count'] = Array(response)[0]

          env
        else
          [status, headers, response]
        end
      end

      def get_count(env)
      end
    end
  end
end
