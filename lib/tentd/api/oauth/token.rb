module TentD
  class API
    module OAuth

      class Token < Middleware
        def action(env)
          halt!(400, "Token code required!") unless Hash === env['data'] && env['data']['code']
          token_code = env['data']['code']

          unless app = Model::App.first(:user_id => env['current_user'].id, :auth_hawk_key => token_code)
            halt!(403, "Invalid token code")
          end

          unless env['current_auth.resource'] && (resource = env['current_auth.resource']) && TentType.new(resource.type).base == %(https://tent.io/types/app) && app.post_id == resource.id
            halt!(401, "Request must be signed using app credentials")
          end

          credentials_post = Model::Post.where(:id => app.auth_credentials_post_id).first
          credentials_post = Model::Credentials.refresh_key(credentials_post)

          env['response'] = {
            :access_token => credentials_post.public_id,
            :hawk_key => credentials_post.content['hawk_key'],
            :hawk_algorithm => credentials_post.content['hawk_algorithm'],
            :token_type => "https://tent.io/oauth/hawk-token"
          }

          env
        end
      end

    end
  end
end
