module TentServer
  class API
    class Followers
      include Router

      class Discover < Middleware
        def action(env, params, response)
          client = ::TentClient.new
          profile = client.discover(params[:data]['entity']).get_profile
          return [404, {}, 'Not Found'] unless profile
          return [409, {}, 'Entity Mismatch'] if profile[profile.keys.first]['entity'] != params[:data]['entity']
          env['profile'] = profile
          env
        end
      end

      class Create < Middleware
        def action(env, params, response)
          if follower = Model::Follow.create_follower(params[:data].merge('profile' => env['profile']))
            env['response'] = follower.as_json(:only => [:id, :mac_key_id, :mac_key, :mac_algorithm])
          end
          env
        end
      end

      class Get < Middleware
        def action(env, params, response)
          if follower = Model::Follow.get(params[:follower_id])
            env['response'] = follower.as_json(:only => [:id, :groups, :entity, :licenses, :type, :mac_key_id, :mac_algorithm])
          end
          env
        end
      end

      post '/followers' do |b|
        b.use Discover
        b.use Create
      end

      get '/followers/:follower_id' do |b|
        b.use Get
      end
    end
  end
end
