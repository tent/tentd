module TentD
  module Model

    class Credentials
      def self.generate(current_user, target_post=nil, options = {})
        type = Type.first_or_create("https://tent.io/types/credentials/v0#")
        published_at_timestamp = (Time.now.to_f * 1000).to_i

        post_attrs = {
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_fragment_id => type.fragment ? type.id : nil,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,
          :received_at => published_at_timestamp,

          :content => {
            :hawk_key => TentD::Utils.hawk_key,
            :hawk_algorithm => TentD::Utils.hawk_algorithm
          },
        }

        if target_post
          post_attrs[:mentions] = [
            { "entity" => current_user.entity, "post" => target_post.public_id }
          ]
        end

        post = Post.create(post_attrs)

        if target_post
          Mention.create(
            :user_id => current_user.id,
            :post_id => post.id,
            :entity_id => current_user.entity_id,
            :post => target_post.public_id
          )

          if options[:bidirectional_mention]
            Mention.link_posts(target_post, post)
          end
        end

        post
      end

      def self.slice_credentials(credentials_post)
        TentD::Utils::Hash.symbolize_keys(credentials_post.as_json[:content]).merge(:id => credentials_post.public_id)
      end

      def self.lookup(current_user, public_id)
        Post.first(
          :user_id => current_user.id,
          :public_id => public_id,
          :type_id => Type.first_or_create("https://tent.io/types/credentials/v0#").id
        )
      end
    end

  end
end
