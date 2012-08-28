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

          if follower = Model::Follow.create_follower(params[:data].merge('profile' => profile))
            env['response'] = follower.as_json(:only => [:id, :mac_key_id, :mac_key, :mac_algorithm])
          end
          env
        end
      end

      post '/followers' do |b|
        b.use Discover
      end
    end
  end
end
