module TentD
  class API
    class Followings
      include Router

      class GetActualId < Middleware
        def action(env)
          id_mapping = [:following_id, :since_id, :before_id].select { |key| env.params.has_key?(key) }.inject({}) { |memo, key|
            memo[env.params[key]] = key
            env.params[key] = nil
            memo
          }
          followings = Model::Following.all(:public_id => id_mapping.keys, :fields => [:id, :public_id])
          followings.each do |following|
            key = id_mapping[following.public_id]
            env.params[key] = following.id
          end
          env
        end
      end

      class AuthorizeWrite < Middleware
        def action(env)
          authorize_env!(env, :write_followings)
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if authorize_env?(env, :read_followings)
            if following = Model::Following.get(env.params.following_id)
              env.following = following
              env.response = following
            end
          else
            following = Model::Following.find_with_permissions(env.params.following_id, env.current_auth)
            if following
              env.response = following
            else
              raise Unauthorized
            end
          end
          env
        end
      end

      class GetMany < Middleware
        def action(env)
          if authorize_env?(env, :read_followings)
            env.response = Model::Following.fetch_all(env.params)
          else
            env.response = Model::Following.fetch_with_permissions(env.params, env.current_auth)
          end
          env
        end
      end

      class Discover < Middleware
        def action(env)
          client = ::TentClient.new(nil, :faraday_adapter => TentD.faraday_adapter)
          profile, profile_url = client.discover(env.params.data.entity).get_profile
          return [404, {}, ['Not Found']] unless profile

          profile = CoreProfileData.new(profile)
          return [409, {}, ['Entity Mismatch']] unless profile.entity?(env.params.data.entity)
          env.profile = profile
          env.server_url = profile_url.sub(%r{/profile$}, '')
          env
        end
      end

      class Follow < Middleware
        def action(env)
          client = ::TentClient.new(env.server_url, :faraday_adapter => TentD.faraday_adapter)
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
          env.response = Model::Following.create_from_params(env.follow_data.merge(env.params.data))
          env
        end
      end

      class Update < Middleware
        def action(env)
          if following = Model::Following.get(env.params.following_id)
            following.update_from_params(env.params.data, env.authorized_scopes)
            env.response = following
          end
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

      class ProxyRequest < Middleware
        def action(env)
          following = env.following
          client = TentClient.new(following.core_profile.servers.first,
                                  following.auth_details.merge(:skip_serialization => true,
                                                               :faraday_adapter => TentD.faraday_adapter))
          env.params.delete(:following_id)
          path = env.params.delete(:proxy_path)
          res = client.http.get(path, env.params, whitelisted_headers(env))
          [res.status, res.headers, [res.body]]
        end

        def whitelisted_headers(env)
          %w(Accept If-Modified-Since).inject({}) do |h,k|
            h[k] = env['HTTP_' + k.gsub('-', '_').upcase]; h
          end
        end
      end

      class RewriteProxyCaptureParams < Middleware
        def action(env)
          matches = env.params.delete(:captures)
          env.params.following_id = matches.first
          env.params.proxy_path = '/' + matches.last
          env
        end
      end

      get '/followings/:following_id' do |b|
        b.use GetActualId
        b.use GetOne
      end

      get '/followings' do |b|
        b.use GetActualId
        b.use GetMany
      end

      get %r{/followings/(\w+)/(.+)} do |b|
        b.use RewriteProxyCaptureParams
        b.use GetActualId
        b.use GetOne
        b.use ProxyRequest
      end

      post '/followings' do |b|
        b.use AuthorizeWrite
        b.use Discover
        b.use Follow
        b.use Create
      end

      put '/followings/:following_id' do |b|
        b.use AuthorizeWrite
        b.use GetActualId
        b.use Update
      end

      delete '/followings/:following_id' do |b|
        b.use AuthorizeWrite
        b.use GetActualId
        b.use Destroy
      end
    end
  end
end
