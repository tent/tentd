module TentServer
  class API
    class Followings
      include Router

      class GetMany < Middleware
        def action(env)
          env.response = Model::Following.fetch_with_permissions(env.params, env.current_auth)
          env
        end
      end

      get '/followings' do |b|
        b.use GetMany
      end
    end
  end
end
