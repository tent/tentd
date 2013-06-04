module TentD
  class API
    module OAuth

      class Token < Middleware
        def action(env)
          halt!(400, "Token code required!") unless Hash === env['data'] && env['data']['code']
          token_code = env['data']['code']

          unless app = Model::App.first(:user_id => env['current_user'].id, :auth_code => token_code)
            halt!(403, "Invalid token code")
          end

          auth_post = Model::Post.qualify.join(:mentions, :posts__public_id => :mentions__post).where(
            :mentions__post_id => app.post_id,
            :posts__type_id => Model::Type.first_or_create("https://tent.io/types/app-auth/v0#").id
          ).order(Sequel.desc(:posts__version_published_at)).first

          credentials_post = Model::Post.qualify.join(:mentions, :posts__public_id => :mentions__post).where(
            :mentions__post_id => auth_post.id,
            :posts__type_id => Model::Type.first_or_create("https://tent.io/types/credentials/v0#").id
          ).first

          unless credentials_post && credentials_post.content['hawk_key'] == token_code
            halt!(403, "Invalid token code!")
          end

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
