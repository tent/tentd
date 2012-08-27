module TentServer
  class API
    class Profile
      include Router

      class Get < Middleware
        def action(env, params, request)
          env['response'] = Model::ProfileInfo.build_for_entity(env['tent.entity'])
          env
        end
      end

      class Update < Middleware
        def action(env, params, request)
          data = JSON.parse(env['rack.input'].read)
          if params[:type_url]
            Model::ProfileInfo.update_type_for_entity(env['tent.entity'], URI.unescape(params[:type_url]), data)
          else
            Model::ProfileInfo.update_for_entity(env['tent.entity'], data)
          end
          env['response'] = Model::ProfileInfo.build_for_entity(env['tent.entity'])
          env
        end
      end

      class Patch < Middleware
        def action(env, params, request)
          diff_array = JSON.parse(env['rack.input'].read)
          profile_hash = Model::ProfileInfo.build_for_entity(env['tent.entity'])
          new_profile_hash = Marshal.load(Marshal.dump(profile_hash)) # equivalent of recursive dup
          JsonPatch.merge(new_profile_hash, diff_array)
          if new_profile_hash != profile_hash
            Model::ProfileInfo.update_for_entity(env['tent.entity'], new_profile_hash)
          end
          env['response'] = new_profile_hash
          env
        rescue JsonPatch::ObjectNotFound, JsonPatch::ObjectExists => e
          env['response.status'] = 422
          env['response'] = profile_hash
          env
        end
      end

      get '/profile' do |b|
        b.use Get
      end

      put '/profile' do |b|
        b.use Update
      end

      put '/profile/:type_url' do |b|
        b.use Update
      end

      patch '/profile' do |b|
        b.use Patch
      end
    end
  end
end
