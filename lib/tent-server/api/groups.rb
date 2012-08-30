module TentServer
  class API
    class Groups
      include Router

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
            group_attributes = env.params[:data]
            group.update(group_attributes)
            env['response'] = group.reload
          end
          env
        end
      end

      class Create < Middleware
        def action(env)
          group_attributes = env.params[:data]
          env['response'] = Model::Group.create!(group_attributes)
          env
        end
      end

      class Destroy < Middleware
        def action(env)
          if (group = Model::Group.get(env.params.group_id)) && group.destroy
            env.response = ''
          end
          env
        end
      end

      get '/groups' do |b|
        b.use GetAll
      end

      get '/groups/:group_id' do |b|
        b.use GetOne
      end

      put '/groups/:group_id' do |b|
        b.use Update
      end

      post '/groups' do |b|
        b.use Create
      end

      delete '/groups/:group_id' do |b|
        b.use Destroy
      end
    end
  end
end
