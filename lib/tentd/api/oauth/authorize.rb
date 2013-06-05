module TentD
  class API
    module OAuth

      class Authorize < Middleware
        def action(env)
          app_post = Model::Post.first(:user_id => env['current_user'].id, :public_id => env['params']['client_id'])
          app_auth_post = Model::AppAuth.create(
            env['current_user'], app_post,
            app_post.content['post_types'],
            app_post.content['scopes']
          )

          credentials_post = nil
          app_auth_post.mentions.each do |m|
            type = Model::Type.find_or_create_full('https://tent.io/types/credentials/v0#')
            if _post = Model::Post.first(:user_id => env['current_user'].id, :public_id => m['post'], :type_id => type.id)
              credentials_post = _post
              break
            end
          end

          hawk_key = credentials_post.content['hawk_key']
          code_param = "code=#{URI.encode_www_form_component(hawk_key)}"
          redirect_uri = URI(app_post.content['redirect_uri'])
          redirect_uri.query ? redirect_uri.query << "&#{code_param}" : redirect_uri.query = code_param

          env['response.headers'] ||= {}
          env['response.headers']['Location'] = redirect_uri.to_s
          env['response.status'] = 302

          env
        end
      end

    end
  end
end
