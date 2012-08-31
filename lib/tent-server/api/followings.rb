module TentServer
  class API
    class Followings
      include Router

      class GetOne < Middleware
        def action(env)
          env.response = Model::Following.find_with_permissions(env.params.following_id, env.current_auth)
          env
        end
      end

      class GetMany < Middleware
        def action(env)
          env.response = Model::Following.fetch_with_permissions(env.params, env.current_auth)
          env
        end
      end

      class Discover < Middleware
        def action(env)
          client = ::TentClient.new
          profile, profile_url = client.discover(env.params.data.entity).get_profile
          return [404, {}, 'Not Found'] unless profile

          profile = CoreProfileData.new(profile)
          return [409, {}, 'Entity Mismatch'] unless profile.entity?(env.params.data.entity)
          env.profile = profile
          env.server_url = profile_url.sub(%r{/profile$}, '')
          env
        end
      end

      class Follow < Middleware
        def action(env)
          client = ::TentClient.new(env.server_url)
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

      class Destroy < Middleware
        def action(env)
          if (following = Model::Following.get(env.params.following_id)) && following.destroy
            env.response = ''
          end
          env
        end
      end

      get '/following/:following_id' do |b|
        b.use GetOne
      end

      get '/followings' do |b|
        b.use GetMany
      end

      post '/followings' do |b|
        b.use Discover
        b.use Follow
        b.use Create
      end

      delete '/followings/:following_id' do |b|
        b.use Destroy
      end
    end
  end
end
