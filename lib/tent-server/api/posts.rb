module TentServer
  class API
    class Posts
      include Router

      class GetOne < Middleware
        def action(env)
          post = Model::Post.first(:id => env.params[:post_id], :public => true)
          if env['current_auth']
            post ||= Model::Post.first(
              :id => env.params[:post_id],
              Model::Post.permissions.group_id => env.current_auth.groups,
              current_auth.permissions.post_id => env.params[:post_id]
            )
          end
          if post
            env['response'] = post
          end
          env
        end
      end

      class GetFeed < Middleware
        def action(env)
          env['response'] = Model::Post.all(conditions_from_params(env.params))
          env
        end

        private

        def conditions_from_params(params)
          conditions = {}
          conditions[:id.gt] = params['since_id'] if params['since_id']
          conditions[:id.lt] = params['before_id'] if params['before_id']
          conditions[:published_at.gt] = Time.at(params['since_time'].to_i) if params['since_time']
          conditions[:published_at.lt] = Time.at(params['before_time'].to_i) if params['before_time']
          conditions[:type] = params['post_types'].split(',').map { |t| URI.parse(URI.unescape(t)) } if params['post_types']
          conditions[:limit] = [(params['limit'] || PER_PAGE).to_i, MAX_PER_PAGE].min
          conditions
        end
      end

      class Create < Middleware
        def action(env)
          post_attributes = env.params[:data]
          post = Model::Post.create!(post_attributes)
          env['response'] = post
          env
        end
      end

      get '/posts/:post_id' do |b|
        b.use GetOne
      end

      get '/posts' do |b|
        b.use GetFeed
      end

      post '/posts' do |b|
        b.use Create
      end
    end
  end
end
