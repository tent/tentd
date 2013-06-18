module TentD
  class API

    class Authorization < Middleware
      def action(env)
        return env unless env['current_auth']

        if Model::Post === env['current_auth'][:credentials_resource]
          type_bases = %w(
            https://tent.io/types/app-auth
            https://tent.io/types/app
            https://tent.io/types/relationship
          )

          credentials_post = env['current_auth'][:credentials_resource]
          mention = credentials_post.mentions.to_a.find do |mention|
            type_bases.include?(TentType.new(mention['type']).base)
          end
          return env unless mention

          resource = Model::Post.where(
            :user_id => env['current_user'].id,
            :public_id => mention['post']
          ).order(Sequel.desc(:version_received_at)).first
          return env unless resource

          env['current_auth.resource'] = resource
        else
          return env
        end

        env
      end
    end

  end
end
