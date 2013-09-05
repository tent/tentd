module TentD
  class API

    class CreatePost < Middleware
      def action(env)
        unless write_authorized?(env)
          halt!(403, "Unauthorized")
        end

        begin
          if TentType.new(env['data']['type']).base == %(https://tent.io/types/app-auth)
            post = Model::AppAuth.create_from_env(env)
          else
            post = Model::Post.create_from_env(env)
          end
        rescue Model::Post::CreateFailure => e
          halt!(400, e.message)
        end

        env['response.post'] = post

        if %w( https://tent.io/types/app https://tent.io/types/app-auth ).include?(TentType.new(post.type).base)
          if TentType.new(post.type).base == "https://tent.io/types/app"
            # app
            credentials_post = Model::Post.first(:id => Model::App.first(:user_id => env['current_user'].id, :post_id => post.id).credentials_post_id)
          else
            # app-auth
            credentials_post = Model::Post.qualify.join(:mentions, :posts__id => :mentions__post_id).where(
              :mentions__post => post.public_id,
              :posts__type_base_id => Model::Type.find_or_create_base('https://tent.io/types/credentials/v0#').id
            ).first
          end

          current_user = env['current_user']
          (env['response.links'] ||= []) << {
            :url => TentD::Utils.sign_url(
              current_user.server_credentials,
              TentD::Utils.expand_uri_template(
                current_user.preferred_server['urls']['post'],
                :entity => current_user.entity,
                :post => credentials_post.public_id
              )
            ),
            :rel => "https://tent.io/rels/credentials"
          }
        end

        env
      end

      private

      def write_authorized?(env)
        writeable_types = %w[
          https://tent.io/types/app
          https://tent.io/types/relationship
        ]

        Authorizer.new(env).write_authorized?(env['data']['entity'], env['data']['type']) ||
        writeable_types.include?(TentType.new(env['data']['type']).base)
      end
    end

  end
end
