module TentD
  class API

    class ServePost < Middleware
      def action(env)
        return env unless Model::Post === (post = env.delete('response.post'))

        params = env['params']

        env['response'] = {
          :post => post.as_json(:env => env)
        }

        authorizer = Authorizer.new(env)

        if env['REQUEST_METHOD'] == 'GET'
          if params['max_refs'] && authorizer.app?
            env['response'][:refs] = Refs.new(env).fetch(post, params['max_refs'].to_i)
          end

          if params['profiles'] && authorizer.app?
            env['response'][:profiles] = MetaProfile.new(env, [post]).profiles(params['profiles'].split(','))
          end
        end

        env['response.headers'] ||= {}
        env['response.headers']['Content-Type'] = POST_CONTENT_TYPE % post.type

        env
      end
    end

  end
end
