module TentD
  class API
    class Followers
      include Router

      class ParseLookupKey < Middleware
        def action(env)
          id_or_entity = env.params.delete(:captures).first

          if id_or_entity =~ /\Ahttps?:\/\//
            env.params.follower_entity = id_or_entity
            follower = Model::Follower.select(:id).first(:user_id => Model::User.current.id, :entity => id_or_entity)
            env.params.follower_id = follower.id if follower
            env.skip_id_lookup = true
          else
            env.params.follower_id = id_or_entity
          end

          env
        end
      end

      class GetActualId < Middleware
        def action(env)
          return env if env.skip_id_lookup
          [:follower_id, :before_id, :since_id].select { |k| env.params.has_key?(k) }.each do |id_key|
            if env.params[id_key] && (f = Model::Follower.select(:id).first(:user_id => Model::User.current.id, :public_id => env.params[id_key]))
              env.params[id_key] = f.id
            else
              env.params[id_key] = nil
            end
          end
          env
        end
      end

      class AuthorizeReadOne < Middleware
        def action(env)
          if env.params.follower_id && env.current_auth && env.current_auth.kind_of?(Model::Follower) &&
                 env.current_auth.id == env.params.follower_id
            env.authorized_scopes << :self
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
          env.authorized_scopes << :self
          env
        end
      end

      class Discover < Middleware
        def action(env)
          return env if env.authorized_scopes.include?(:write_followers)
          return error_response(400, 'Request body required') unless env.params.data
          return error_response(422, 'Invalid notification path') unless env.params.data.notification_path.kind_of?(String) &&
                                                                !env.params.data.notification_path.match(%r{\Ahttps?://})
          return error_response(406, 'Can not follow self') if Model::User.current.profile_entity == env.params.data.entity
          client = ::TentClient.new(nil, :faraday_adapter => TentD.faraday_adapter)
          begin
            profile, profile_url = client.discover(env.params[:data]['entity']).get_profile
          rescue Faraday::Error::ConnectionFailed
            return error_response(503, "Couldn't connect to entity")
          rescue Faraday::Error::TimeoutError
            return error_response(504, 'Connection to entity timed out')
          end

          raise NotFound unless profile

          profile = CoreProfileData.new(profile)
          env['profile'] = profile
          env
        end
      end

      class Confirm < Middleware
        def action(env)
          return env if env.authorized_scopes.include?(:write_followers)
          client = TentClient.new(env.profile.servers, :faraday_adapter => TentD.faraday_adapter)
          if client.follower.challenge(env.params.data.notification_path)
            env
          else
            raise Unauthorized
          end
        end
      end

      class Create < Middleware
        def action(env)
          return env if env.authorized_scopes.include?(:write_followers)
          if follower = Model::Follower.create_follower(env.params[:data].merge('profile' => env['profile']))
            env.authorized_scopes << :read_secrets
            env.authorized_scopes << :self
            env.notify_action = 'create'
            env.notify_instance = follower
            env.response = follower
          end
          env
        end
      end

      class Import < Middleware
        def action(env)
          return env unless env.authorized_scopes.include?(:write_followers)
          if env.authorized_scopes.include?(:write_secrets)
            data = env.params.data
            data.public_id = data.delete(:id) if data.id
            if follower = Model::Follower.create_follower(data, env.authorized_scopes)
              env.response = ''
            end
          else
            raise Unauthorized
          end
          env
        end
      end

      class EntityRedirect < Middleware
        def action(env)
          return env unless env.params.has_key?(:follower_entity)

          follower = Model::Follower.select(:id, :public, :public_id).where(:entity => env.params.follower_entity, :user_id => Model::User.current.id).first
          if follower && !follower.public? && !(env.full_read_authorized || authorize_env?(env, :self))
            follower = Model::Follower.find_with_permissions(follower.id, env.current_auth)
            raise Unauthorized unless follower
          end

          unless follower
            raise Unauthorized unless env.full_read_authorized
            return env # 404
          end

          redirect_uri = self_uri(env)
          redirect_uri.path = "/followers/#{follower.public_id}"
          [302, { 'Location' => redirect_uri.to_s }, []]
        end
      end

      class GetOne < Middleware
        def action(env)
          return env if env.params.has_key?(:follower_entity)

          if env.full_read_authorized || authorize_env?(env, :self)
            follower = Model::Follower.first(:id => env.params.follower_id)
          else
            follower = Model::Follower.find_with_permissions(env.params.follower_id, env.current_auth)
          end

          if env.full_read_authorized || authorize_env?(env, :self) || (follower && follower.public?)
            env.response = follower
          else
            raise Unauthorized
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
          if env.full_read_authorized
            followers = Model::Follower.fetch_all(env.params)
          else
            followers = Model::Follower.fetch_with_permissions(env.params, env.current_auth)
          end
          env.response = followers if followers
          env
        end
      end

      class CountHeader < Middleware
        def action(env)
          count_env = env.dup
          count_env.params.return_count = true
          count = GetMany.new(@app).call(count_env)[2][0]

          env['response.headers'] ||= {}
          env['response.headers']['Count'] = count

          env
        end
      end

      class PaginationHeader < API::PaginationHeader
      end

      class Update < Middleware
        def action(env)
          env.response = Model::Follower.update_follower(env.params[:follower_id], env.params[:data], env.authorized_scopes)
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (follower = Model::Follower.first(:id => env.params[:follower_id])) && follower.destroy
            env.notify_action = 'delete'
            env.notify_instance = follower
            env.response = ''
          end
          env
        end
      end

      class Notify < Middleware
        def action(env)
          return env unless follower = env.notify_instance
          post = Model::Post.create(
            :type => 'https://tent.io/types/post/follower/v0.1.0',
            :entity => env['tent.entity'],
            :original => true,
            :content => {
              :id => follower.public_id,
              :entity => follower.entity,
              :action => env.notify_action
            }
          )
          Model::Permission.copy(follower, post)
          Notifications.trigger(:type => post.type.uri, :post_id => post.id)
          env
        end
      end

      post '/followers' do |b|
        b.use Discover
        b.use Confirm
        b.use Create
        b.use Import
        b.use Notify
      end

      get '/followers/count' do |b|
        b.use AuthorizeReadMany
        b.use GetActualId
        b.use GetCount
        b.use GetMany
      end

      get %r{/followers/([^/]+)} do |b|
        b.use ParseLookupKey
        b.use GetActualId
        b.use AuthorizeReadOne
        b.use EntityRedirect
        b.use GetOne
      end

      head '/followers' do |b|
        b.use AuthorizeReadMany
        b.use GetActualId
        b.use GetMany
        b.use PaginationHeader
        b.use CountHeader
      end

      get '/followers' do |b|
        b.use AuthorizeReadMany
        b.use GetActualId
        b.use GetMany
        b.use PaginationHeader
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
        b.use Notify
      end
    end
  end
end
