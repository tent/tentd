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
          if env.params.group_id
            if g = Model::Group.first(:public_id => env.params.group_id)
              env.params.group_id = g.id
            else
              env.params.group_id = nil
            end
          end
          env
        end
      end

      class GetAll < Middleware
        def action(env)
          env['response'] = Model::Group.all
          env
        end
      end

      class GetOne < Middleware
        def action(env)
          if group = Model::Group.get(env.params[:group_id])
            env['response'] = group
          end
          env
        end
      end

      class Update < Middleware
        def action(env)
          if group = Model::Group.get(env.params[:group_id])
            group.update(:name => env.params.data.name)
            env['response'] = group.reload
          end
          env
        end
      end

      class Create < Middleware
        def action(env)
          group_attributes = env.params[:data]
          if group = Model::Group.create(group_attributes)
            env.response = group
            env.notify_action = 'create'
            env.notify_instance = group
          end
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (group = Model::Group.get(env.params.group_id)) && group.destroy
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
            :content => {
              :id => group.public_id,
              :name => group.name,
              :action => env.notify_action
            }
          )
          Notifications::TRIGGER_QUEUE << { :type => post.type, :post_id => post.id }
          env
        end
      end

      get '/groups' do |b|
        b.use AuthorizeRead
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
