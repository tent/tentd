module TentD
  class API
    class Groups
      include Router

      class AuthorizeRead < Middleware
        def action(env)
          authorize_env!(env, :read_groups)
          env
        end
      end

      class AuthorizeWrite < Middleware
        def action(env)
          authorize_env!(env, :write_groups)
          env
        end
      end

      class GetActualId < Middleware
        def action(env)
          [:group_id, :before_id, :since_id].select { |k| env.params.has_key?(k) }.each do |id_key|
            if env.params[id_key]
              if g = Model::Group.first(:public_id => env.params[id_key])
                env.params[id_key] = g.id
              else
                env.params[id_key] = nil
              end
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

      class GetAll < Middleware
        def action(env)
          if (env.params.has_key?(:since_id) && env.params.since_id.nil?) || (env.params.has_key?(:before_id) && env.params.before_id.nil?)
            env.response = []
            return
          end

          conditions = {}
          conditions[:id.lt] = env.params.before_id if env.params.before_id
          conditions[:id.gt] = env.params.since_id if env.params.since_id
          conditions[:limit] = [env.params.limit.to_i, MAX_PER_PAGE].min if env.params.limit
          conditions[:limit] ||= PER_PAGE
          if env.params.return_count
            env.response = Model::Group.count(conditions)
          else
            if env.params.order == 'asc'
              conditions[:order] = :id.asc
            else
              conditions[:order] = :id.desc
            end

            if conditions[:limit] == 0
              env.response = []
            else
              env.response = Model::Group.all(conditions)
            end
          end
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if group = Model::Group.first(:id => env.params[:group_id])
            env['response'] = group
          end
          env
        end
      end

      class Update < Middleware
        def action(env)
          if group = Model::Group.first(:id => env.params[:group_id])
            group.update(:name => env.params.data.name)
            env['response'] = group.reload
          end
          env
        end
      end

      class Create < Middleware
        def action(env)
          data = env.params.data
          data.public_id = data.delete(:id) if data.id
          data.slice!(:public_id, :name)
          begin
            if group = Model::Group.create(data)
              env.response = group
              env.notify_action = 'create'
              env.notify_instance = group
            end
          rescue DataObjects::IntegrityError # hack to ignore duplicate groups
            env.response = Model::Group.first(:public_id => data.public_id)
          end
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (group = Model::Group.first(:id => env.params.group_id)) && group.destroy
            env.response = ''
            env.notify_action = 'delete'
            env.notify_instance = group
          end
          env
        end
      end

      class Notify < Middleware
        def action(env)
          return env unless group = env.notify_instance
          post = Model::Post.create(
            :type => 'https://tent.io/types/post/group/v0.1.0',
            :entity => env['tent.entity'],
            :original => true,
            :content => {
              :id => group.public_id,
              :name => group.name,
              :action => env.notify_action
            }
          )
          Notifications.trigger(:type => post.type.uri, :post_id => post.id)
          env
        end
      end

      get '/groups' do |b|
        b.use AuthorizeRead
        b.use GetActualId
        b.use GetAll
      end

      get '/groups/count' do |b|
        b.use AuthorizeRead
        b.use GetActualId
        b.use GetCount
        b.use GetAll
      end

      get '/groups/:group_id' do |b|
        b.use AuthorizeRead
        b.use GetActualId
        b.use GetOne
      end

      put '/groups/:group_id' do |b|
        b.use AuthorizeWrite
        b.use GetActualId
        b.use Update
      end

      post '/groups' do |b|
        b.use AuthorizeWrite
        b.use Create
        b.use Notify
      end

      delete '/groups/:group_id' do |b|
        b.use AuthorizeWrite
        b.use GetActualId
        b.use Destroy
        b.use Notify
      end
    end
  end
end
