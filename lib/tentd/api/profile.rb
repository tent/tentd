module TentD
  class API
    class Profile
      include Router

      class AuthorizeWrite < Middleware
        def action(env)
          authorize_env!(env, :write_profile)
          env
        end
      end

      class Get < Middleware
        def action(env)
          env.response = Model::ProfileInfo.get_profile(env.authorized_scopes, env.current_auth)
          env
        end
      end

      class Update < Middleware
        def action(env)
          data = env.params.data
          type = URI.unescape(env.params.type_url)
          raise Unauthorized unless ['all', type].find { |t| env.current_auth.profile_info_types.include?(t) }
          Model::ProfileInfo.update_profile(type, data)
          env.notify_types = [type]
          env
        end
      end

      class Patch < Middleware
        def action(env)
          diff_array = env.params[:data]
          profile_hash = env.delete(:response)
          new_profile_hash = Marshal.load(Marshal.dump(profile_hash)).to_hash # equivalent of recursive dup
          JsonPatch.merge(new_profile_hash, diff_array)
          if new_profile_hash != profile_hash
            new_profile_hash.each_pair do |type, data|
              Model::ProfileInfo.update_profile(type, data)
            end
          end
          env.response = new_profile_hash
          env.notify_types = new_profile_hash.keys
          env
        rescue JsonPatch::ObjectNotFound, JsonPatch::ObjectExists => e
          env['response.status'] = 422
          env.response = profile_hash
          env
        end
      end

      class Notify < Middleware
        def action(env)
          return env unless env.notify_types
          post = Model::Post.create(
            :type => 'https://tent.io/types/post/profile/v0.1.0',
            :entity => env['tent.entity'],
            :content => {
              :action => 'update',
              :types => env.notify_types,
            }
          )
          Notifications.trigger(:type => post.type, :post_id => post.id)
          env
        end
      end

      get '/profile' do |b|
        b.use Get
      end

      put '/profile/:type_url' do |b|
        b.use AuthorizeWrite
        b.use Update
        b.use Get
        b.use Notify
      end

      patch '/profile' do |b|
        b.use AuthorizeWrite
        b.use Get
        b.use Patch
        b.use Notify
      end
    end
  end
end
