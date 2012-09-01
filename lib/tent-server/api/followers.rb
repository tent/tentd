module TentServer
  class API
    class Followers
      include Router

      class GetActualId < Middleware
        def action(env)
          if env.params.follower_id && (follower = Model::Follower.first(:public_uid => env.params.follower_id, :fields => [:id]))
            env.params.follower_id = follower.id
          else
            env.params.follower_id = nil
          end
          env
        end
      end

      class AuthorizeReadOne < Middleware
        def action(env)
          if env.params.follower_id && env.current_auth && env.current_auth.kind_of?(Model::Follower) &&
                 env.current_auth.id == env.params.follower_id
            env.single_read_authorized = true
          end
          env.full_read_authorized = authorize_env?(env, :read_followers)
          env
        end
      end

      class AuthorizeReadMany < Middleware
        def action(env)
          env.full_read_authorized = authorize_env?(env, :read_followers)
          env
        end
      end

      class AuthorizeWriteOne < Middleware
        def action(env)
          unless env.params.follower_id && env.current_auth && env.current_auth.kind_of?(Model::Follower) &&
                 env.current_auth.id == env.params.follower_id
            authorize_env!(env, :write_followers)
          end
          env
        end
      end

      class Discover < Middleware
        def action(env)
          client = ::TentClient.new
          profile, profile_url = client.discover(env.params[:data]['entity']).get_profile
          return [404, {}, 'Not Found'] unless profile

          profile = CoreProfileData.new(profile)
          return [409, {}, 'Entity Mismatch'] unless profile.entity?(env.params.data.entity)
          env['profile'] = profile
          env
        end
      end

      class Create < Middleware
        def action(env)
          if follower = Model::Follower.create_follower(env.params[:data].merge('profile' => env['profile']))
            env['response'] = follower.as_json(:only => [:id, :mac_key_id, :mac_key, :mac_algorithm])
          end
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if env.full_read_authorized || env.single_read_authorized
            follower = Model::Follower.find(env.params.follower_id)
          else
            follower = Model::Follower.find_with_permissions(env.params.follower_id, env.current_auth)
          end

          if follower && (env.full_read_authorized || env.single_read_authorized)
            if authorize_env?(env, :read_secrets)
              env['response'] = follower.as_json(:only => [:id, :groups, :entity, :licenses, :mac_key_id, :mac_key, :mac_algorithm, :mac_timestamp_delta], :authorized_scopes => env.authorized_scopes)
            else
              env['response'] = follower.as_json(:only => [:id, :groups, :entity, :licenses, :mac_key_id, :mac_algorithm])
            end
          elsif follower && follower.public?
            env['response'] = follower.as_json(:only => [:id, :groups, :entity, :licenses])
          elsif !env.full_read_authorized
            raise Unauthorized
          end
          env
        end
      end

      class GetMany < Middleware
        def action(env)
          if env.full_read_authorized
            followers = Model::Follower.fetch_all(env.params)
          else
            followers = Model::Follower.fetch_with_permissions(env.params, env.current_auth)
          end
          if followers
            env['response'] = followers.map { |f|
              f.as_json(:authorized_scopes => env.authorized_scopes)
            }
          end
          env
        end
      end

      class Update < Middleware
        def action(env)
          Model::Follower.update_follower(env.params[:follower_id], env.params[:data], env.authorized_scopes)
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (follower = Model::Follower.get(env.params[:follower_id])) && follower.destroy
            env['response'] = ''
          end
          env
        end
      end

      post '/followers' do |b|
        b.use Discover
        b.use Create
      end

      get '/followers/:follower_id' do |b|
        b.use GetActualId
        b.use AuthorizeReadOne
        b.use GetOne
      end

      get '/followers' do |b|
        b.use AuthorizeReadMany
        b.use GetMany
      end

      put '/followers/:follower_id' do |b|
        b.use GetActualId
        b.use AuthorizeWriteOne
        b.use Update
      end

      delete '/followers/:follower_id' do |b|
        b.use GetActualId
        b.use AuthorizeWriteOne
        b.use Destroy
      end
    end
  end
end
