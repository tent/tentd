require 'rack-putty'

module TentD
  class API

    POST_CONTENT_MIME = %(application/vnd.tent.post.v0+json).freeze
    MULTIPART_CONTENT_MIME = %(multipart/form-data).freeze

    POST_CONTENT_TYPE = %(#{POST_CONTENT_MIME}; type="%s").freeze
    ERROR_CONTENT_TYPE = %(application/vnd.tent.error.v0+json).freeze
    MULTIPART_CONTENT_TYPE = MULTIPART_CONTENT_MIME
    ATTACHMENT_DIGEST_HEADER = %(Attachment-Digest).freeze

    require 'tentd/api/serialize_response'
    require 'tentd/api/middleware'
    require 'tentd/api/user_lookup'
    require 'tentd/api/authentication'
    require 'tentd/api/parse_input_data'
    require 'tentd/api/parse_content_type'
    require 'tentd/api/parse_link_header'
    require 'tentd/api/validate_input_data'
    require 'tentd/api/validate_post_content_type'
    require 'tentd/api/relationship_initialization'

    include Rack::Putty::Router

    stack_base SerializeResponse

    middleware UserLookup
    middleware Authentication
    middleware ParseInputData
    middleware ParseContentType
    middleware ParseLinkHeader
    middleware ValidateInputData

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

        [201, headers, []]
      end
    end

    class GetPost < Middleware
      def action(env)
        params = env['params']
        env['response'] = Model::Post.first(:public_id => params[:post], :entity => params[:entity])
        env
      end
    end

    class CreatePost < Middleware
      def action(env)
        if env['request.notification']
          case env['request.type'].base
          when "https://tent.io/types/relationship"
            RelationshipInitialization.call(env)
          end
        else
          post = Model::Post.create_from_env(env)
          env['response'] = post

          if %w( https://tent.io/types/app https://tent.io/types/app-auth ).include?(TentType.new(post.type).base) && !env['request.import']
            credentials_post = Model::Credentials.generate(env['current_user'], env['response'])
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
        end
        env
      end
    end

    class PostsFeed < Middleware
      def action(env)
        env['response'] = Feed.new(env)
        env
      end
    end

    head '/' do |b|
      b.use HelloWorld
    end

    post '/posts' do |b|
      b.use ValidatePostContentType
      b.use CreatePost
    end

    get '/posts/:entity/:post' do |b|
      b.use GetPost
    end

    get '/posts' do |b|
      b.use PostsFeed
    end

  end
end
