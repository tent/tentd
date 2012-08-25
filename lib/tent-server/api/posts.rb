require 'tent-server/core_ext/hash/slice'

module TentServer
  class API
    class Posts
      include Router

      class GetOne < Middleware
        def action(env, params, request)
          if post = ::TentServer::Model::Post.get(params[:post_id])
            env['response'] = post
          end
          env
        end
      end

      class GetFeed < Middleware
        def action(env, params, request)
          params.slice!(*%w{ post_types since_id before_id since_time before_time limit })
          env['response'] = ::TentServer::Model::Post.all(conditions_from_params(params))
          env
        end

        private

        def conditions_from_params(params)
          conditions = {}
          conditions[:id.gt] = params['since_id'] if params['since_id']
          conditions[:limit] = (params['limit'] || PER_PAGE).to_i
          conditions
        end
      end

      class Create < Middleware
        def action(env, params, request)
          post_attributes = JSON.parse(env['rack.input'].read)
          post = ::TentServer::Model::Post.create!(post_attributes)
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
