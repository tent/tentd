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

      class Discover < Middleware
        def action(env)
          client = ::TentClient.new
          profile = client.discover(env.params.data.entity).get_profile
          return [404, {}, 'Not Found'] unless profile
          return [409, {}, 'Entity Mismatch'] if profile[Model::ProfileInfo::TENT_PROFILE_TYPE_URI]['entity'] != env.params.data.entity
          env.profile = profile
          env
        end
      end

      class Follow < Middleware
        def action(env)
          client = ::TentClient.new(env.params.data.entity)
          res = client.follower.create(
            :entity => env['tent.entity'],
            :licenses => Model::ProfileInfo.tent_info(env['tent.entity']).content['licenses']
          )
          case res.status
          when 200...300
            env.follow_data = res.body
          else
            return [res.status, res.headers, res.body]
          end
          env
        end
      end

      class Create < Middleware
        def action(env)
          env.response = Model::Following.create_from_params(env.params.data.merge(env.follow_data))
          env
        end
      end

      get '/followings' do |b|
        b.use GetMany
      end

      post '/followings' do |b|
        b.use Discover
        b.use Follow
        b.use Create
      end
    end
  end
end
