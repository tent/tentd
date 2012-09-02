module TentServer
  class API
    class Groups
      include Router

      class GetActualId < Middleware
        def action(env)
          if env.params.group_id
            if g = Model::Group.first(:public_uid => env.params.group_id)
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
        b.use GetActualId
        b.use GetOne
      end

      put '/groups/:group_id' do |b|
        b.use GetActualId
        b.use Update
      end

      post '/groups' do |b|
        b.use Create
      end

      delete '/groups/:group_id' do |b|
        b.use GetActualId
        b.use Destroy
      end
    end
  end
end
