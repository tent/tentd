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
            if following = Model::Following.first(:id => env.params.following_id, :confirmed => true)
              env.following = following
              env.response = following
            end
          else
            following = Model::Following.find_with_permissions(env.params.following_id, env.current_auth) { |p,q,b| q << 'AND followings.confirmed = true' }
            if following
              env.response = following
            else
              raise Unauthorized
            end
          end
          env
        end
      end

      class GetCount < Middleware
        def action(env)
          env.params.return_count = true
          env
        end
      end

      class GetMany < Middleware
        def action(env)
          if authorize_env?(env, :read_followings)
            env.response = Model::Following.fetch_all(env.params) { |p,q,b| q << 'followings.confirmed = true' }
          else
            env.response = Model::Following.fetch_with_permissions(env.params, env.current_auth) { |p,q,b| q << 'AND followings.confirmed = true' }
          end
          env
        end
      end

      class Discover < Middleware
        def action(env)
          return [422, {}, ['Invalid Request Body']] unless env.params.data
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
          if Model::Following.all(:entity => env.params.data.entity).any?
            return [409, {}, ['Already following']]
          end

          env.following = Model::Following.create(:entity => env.params.data.entity,
                                                  :groups => env.params.data.groups.to_a.map { |g| g['id'] },
                                                  :confirmed => false)
          client = ::TentClient.new(env.server_url, :faraday_adapter => TentD.faraday_adapter)
          res = client.follower.create(
            :entity => env['tent.entity'],
            :licenses => Model::ProfileInfo.tent_info.content['licenses'],
            :notification_path => "notifications/#{env.following.public_id}"
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
          if env.following.confirm_from_params(env.follow_data.merge(env.params.data).merge(:profile => env.profile))
            env.response = env.following
            env.notify_action = 'create'
            env.notify_instance = env.following
          end
          env
        end
      end

      class Update < Middleware
        def action(env)
          if following = Model::Following.first(:id => env.params.following_id)
            following.update_from_params(env.params.data, env.authorized_scopes)
            env.response = following
          end
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (following = Model::Following.first(:id => env.params.following_id))
            client = ::TentClient.new(following.core_profile.servers, following.auth_details.merge(:faraday_adapter => TentD.faraday_adapter))
            res = client.follower.delete(following.remote_id)
            following.destroy
            env.response = ''
            if (200...300).to_a.include?(res.status)
              env.notify_action = 'delete'
              env.notify_instance = following
            end
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

      class Notify < Middleware
        def action(env)
          return env unless following = env.notify_instance
          post = Model::Post.create(
            :type => 'https://tent.io/types/post/following/v0.1.0',
            :entity => env['tent.entity'],
            :content => {
              :id => following.public_id,
              :entity => following.entity,
              :action => env.notify_action
            }
          )
          Notifications.trigger(:type => post.type.uri, :post_id => post.id)
          env
        end
      end

      class RedirectToFollowUI < Middleware
        def action(env)
          if follow_url = Model::AppAuthorization.follow_url(env.params.entity)
            return [302, { "Location" => follow_url }, []]
          end
          env
        end
      end

      get '/follow' do |b|
        b.use RedirectToFollowUI
      end

      get '/followings/count' do |b|
        b.use GetActualId
        b.use GetCount
        b.use GetMany
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
        b.use Notify
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
        b.use Notify
      end
    end
  end
end
