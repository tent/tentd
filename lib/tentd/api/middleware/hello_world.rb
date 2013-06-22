module TentD
  class API

    class HelloWorld < Middleware
      def action(env)
        meta_post_url = TentD::Utils.expand_uri_template(
          env['current_user'].preferred_server['urls']['post'],
          :entity => env['current_user'].entity,
          :post => env['current_user'].meta_post.public_id
        )

        headers = {
          'Link' => %(<#{meta_post_url}>; rel="https://tent.io/rels/meta-post")
        }

        [200, headers, ['Tent!']]
      end
    end

  end
end
