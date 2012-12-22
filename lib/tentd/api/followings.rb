module TentD
  class API
    class Followings
      include Router

      class ParseLookupKey < Middleware
        def action(env)
          id_or_entity = env.params.delete(:captures).first

          if id_or_entity =~ /^https?:\/\//
            env.params.following_entity = id_or_entity
            following = Model::Following.select(:id).first(:user_id => Model::User.current.id, :entity => id_or_entity)
            env.params.following_id = following.id if following
            env.skip_id_lookup = true
          else
            env.params.following_id = id_or_entity
          end

          env
        end
      end

      class GetActualId < Middleware
        def action(env)
          return env if env.skip_id_lookup
          id_mapping = [:following_id, :since_id, :before_id].select { |key| env.params.has_key?(key) }.inject({}) { |memo, key|
            memo[env.params[key]] = key
            env.params[key] = nil
            memo
          }
          return env unless id_mapping.keys.any?
          followings = Model::Following.unfiltered.select(:id, :public_id).where(:user_id => Model::User.current.id, :public_id => id_mapping.keys).all
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

      class EntityRedirect < Middleware
        def action(env)
          return env unless env.params.has_key?(:following_entity)

          following = Model::Following.select(:id, :public, :public_id).where(:entity => env.params.following_entity, :user_id => Model::User.current.id).first
          if following && !following.public && !authorize_env?(env, :read_followings)
            following = Model::Following.find_with_permissions(following.id, env.current_auth)
          end

          raise NotFound unless following

          redirect_uri = self_uri(env)
          redirect_uri.path = env.SCRIPT_NAME.sub(%r{/followings/.*\Z}, "/followings/#{following.public_id}")
          env['response.headers'] ||= {}
          env['response.headers']['Content-Location'] = redirect_uri.to_s
          env.response = following
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
              raise NotFound
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
            env.response = Model::Following.fetch_all(env.params) { |p,q,qc,b| qc << 'followings.confirmed = true' }
          else
            env.response = Model::Following.fetch_with_permissions(env.params, env.current_auth) { |p,q,b| q << 'AND followings.confirmed = true' }
          end
          env
        end
      end

      class CountHeader < API::CountHeader
        def get_count(env)
          count = GetMany.new(@app).call(env)
        end
      end

      class PaginationHeader < API::PaginationHeader
      end

      class Discover < Middleware
        def action(env)
          return error_response(422, 'Invalid Request Body') unless env.params.data && env.params.data.entity
          client = ::TentClient.new(nil, :faraday_adapter => TentD.faraday_adapter)
          profile, profile_url = client.discover(env.params.data.entity).get_profile
          raise NotFound unless profile

          profile = CoreProfileData.new(profile)
          env.profile = profile
          env.server_url = profile_url.sub(%r{/profile$}, '')
          env
        rescue Faraday::Error::ConnectionFailed
          raise NotFound
        end
      end

      class Follow < Middleware
        def action(env)
          existing_following = Model::Following.first(:user_id => Model::User.current.id, :entity => env.params.data.entity)
          if existing_following && existing_following.confirmed == true
            return error_response(409, 'Already following')
          end

          if existing_following
            env.following = existing_following
            env.notify = false
          else
            env.following = Model::Following.create(:entity => env.params.data.entity,
                                                    :groups => env.params.data.groups.to_a.map { |g| g['id'] },
                                                    :confirmed => false)
          end

          data = env.params.data
          if authorize_env?(env, :write_secrets) && data.mac_key_id && data.mac_key && data.mac_algorithm
            data.public_id = data.delete(:id) if data.id
            data.slice!(:public_id, :mac_key_id, :mac_key, :mac_algorithm)
            data[:confirmed] = true
            env.following.update(data)
          else
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
              body = res.body.kind_of?(String) ? res.body : res.body.to_json
              return [res.status, res.headers, [body]]
            end
          end
          env
        end
      end

      class Create < Middleware
        def action(env)
          if (authorize_env?(env, :write_secrets) && !env.follow_data) || env.following.confirm_from_params(env.follow_data.merge(env.params.data).merge(:profile => env.profile))
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
          return env unless env.following
          following = env.following
          client = TentClient.new(following.core_profile.servers,
                                  following.auth_details.merge(:skip_serialization => true,
                                                               :faraday_adapter => TentD.faraday_adapter))
          env.params.delete(:following_id)
          path = env.params.delete(:proxy_path).sub(%r{\A/}, '')
          res = client.http.get(path, env.params, whitelisted_headers(env))
          [res.status, res.headers, [res.body]]
        end

        def whitelisted_headers(env)
          %w(Accept If-Modified-Since).inject({}) do |h,k|
            h[k] = env['HTTP_' + k.gsub('-', '_').upcase].to_s; h
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
          return env if env.has_key?(:notify) && !env.notify
          return env unless following = env.notify_instance
          post = Model::Post.create(
            :type => 'https://tent.io/types/post/following/v0.1.0',
            :entity => env['tent.entity'],
            :original => true,
            :content => {
              :id => following.public_id,
              :entity => following.entity,
              :action => env.notify_action
            }
          )
          Model::Permission.copy(following, post)
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

      head '/followings' do |b|
        b.use GetActualId
        b.use GetMany
        b.use PaginationHeader
        b.use CountHeader
      end

      get '/followings' do |b|
        b.use GetActualId
        b.use GetMany
        b.use PaginationHeader
      end

      get %r{/followings/(\w+)/(.+)} do |b|
        b.use RewriteProxyCaptureParams
        b.use GetActualId
        b.use GetOne
        b.use ProxyRequest
      end

      get %r{/followings/([^/]+)} do |b|
        b.use ParseLookupKey
        b.use GetActualId
        b.use EntityRedirect
        b.use GetOne
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
