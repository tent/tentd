module TentD
  class API
    module OAuth

      class Authorize < Middleware
        def action(env)
          ##
          # Only activate this endpoint when oauth_auth url points here (no app has taken responsibility)
          oauth_auth_url = "#{env['current_user'].entity}/oauth/authorize"
          halt!(404) unless env['current_user'].meta_post.content['servers'].any? do |server|
            server['urls']['oauth_auth'] == oauth_auth_url
          end

          halt!(400, "client_id missing") if env['params']['client_id'].to_s == ""

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
          code_param += "&state=#{env['params']['state']}" if env['params']['state']
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
