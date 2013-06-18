require 'rack-putty'

module TentD
  class API

    CREDENTIALS_LINK_REL = %(https://tent.io/rels/credentials).freeze

    POST_CONTENT_MIME = %(application/vnd.tent.post.v0+json).freeze
    MULTIPART_CONTENT_MIME = %(multipart/form-data).freeze

    CREDENTIALS_MIME_TYPE = %(https://tent.io/types/credentials/v0#).freeze
    RELATIONSHIP_MIME_TYPE = %(https://tent.io/types/relationship/v0#).freeze

    POST_CONTENT_TYPE = %(#{POST_CONTENT_MIME}; type="%s").freeze
    ERROR_CONTENT_TYPE = %(application/vnd.tent.error.v0+json).freeze
    MULTIPART_CONTENT_TYPE = MULTIPART_CONTENT_MIME
    ATTACHMENT_DIGEST_HEADER = %(Attachment-Digest).freeze

    MENTIONS_CONTENT_TYPE = %(application/vnd.tent.post-mentions.v0+json).freeze
    CHILDREN_CONTENT_TYPE = %(application/vnd.tent.post-children.v0+json).freeze
    VERSIONS_CONTENT_TYPE = %(application/vnd.tent.post-versions.v0+json).freeze

    require 'tentd/api/serialize_response'
    require 'tentd/api/cors_headers'
    require 'tentd/api/middleware'
    require 'tentd/api/user_lookup'
    require 'tentd/api/user_lookup'
    require 'tentd/api/authentication'
    require 'tentd/api/authorization'
    require 'tentd/api/parse_input_data'
    require 'tentd/api/parse_content_type'
    require 'tentd/api/parse_link_header'
    require 'tentd/api/validate_input_data'
    require 'tentd/api/validate_post_content_type'
    require 'tentd/api/relationship_initialization'
    require 'tentd/api/notification_importer'
    require 'tentd/api/oauth'

    require 'tentd/api/meta_profile'

    include Rack::Putty::Router

    stack_base SerializeResponse

    middleware CorsHeaders
    middleware UserLookup
    middleware Authentication
    middleware Authorization
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

        [200, headers, ['Tent!']]
      end
    end

    class NotFound < Middleware
      def action(env)
        halt!(404, "Not Found")
      end
    end

    class ListPostMentions < Middleware
      def action(env)
        ref_post = env.delete('response.post')

        q = Query.new(Model::Post)

        q.select_columns = %w( posts.entity posts.entity_id posts.public_id posts.type mentions.public )

        q.query_conditions << "posts.user_id = ?"
        q.query_bindings << env['current_user'].id

        q.join("INNER JOIN mentions ON mentions.post_id = posts.id")

        q.query_conditions << "mentions.post = ?"
        q.query_bindings << ref_post.public_id

        if env['current_auth'] && (auth_candidate = Authorizer::AuthCandidate.new(env['current_user'], env['current_auth.resource'])) && auth_candidate.read_type?(ref_post.type)
          q.query_conditions << "(mentions.public = true OR posts.entity_id = ?)"
          q.query_bindings << env['current_user'].entity_id
        else
          q.query_conditions << "mentions.public = true"
        end

        q.sort_columns = ["posts.received_at DESC"]

        q.limit = Feed::DEFAULT_PAGE_LIMIT

        posts = q.all

        env['response'] = {
          :mentions => posts.map { |post|
            m = { :type => post.type, :post => post.public_id }
            m[:entity] = post.entity unless ref_post.entity == post.entity
            m[:public] = false if post.public == false
            m
          }
        }

        if env['params']['profiles']
          env['response'][:profiles] = MetaProfile.new(env['current_user'].id, posts).profiles(
            env['params']['profiles'].split(',') & ['entity']
          )
        end

        env['response.headers'] = {}
        env['response.headers']['Content-Type'] = MENTIONS_CONTENT_TYPE

        env
      end
    end

    class ListPostChildren < Middleware
      def action(env)
        ref_post = env.delete('response.post')

        q = Query.new(Model::Post)

        q.query_conditions << "posts.user_id = ?"
        q.query_bindings << env['current_user'].id

        q.join("INNER JOIN parents ON parents.post_id = posts.id")

        q.query_conditions << "parents.parent_post_id = ?"
        q.query_bindings << ref_post.id

        authorizer = Authorizer.new(env)
        if env['current_auth'] && authorizer.auth_candidate
          unless authorizer.auth_candidate.read_all_types?
            _read_type_ids = Model::Type.find_types(authorizer.auth_candidate.read_types).inject({:base => [], :full => []}) do |memo, type|
              if type.fragment.nil?
                memo[:base] << type.id
              else
                memo[:full] << type.id
              end
              memo
            end

            q.query_conditions << ["OR",
              "posts.public = true",
              ["AND",
                "posts.entity_id = ?",
                ["OR",
                  "posts.type_base_id IN ?",
                  "posts.type_id IN ?"
                ]
              ]
            ]
            q.query_bindings << env['current_user'].entity_id
            q.query_bindings << _read_type_ids[:base]
            q.query_bindings << _read_type_ids[:full]
          end
        else
          q.query_conditions << "posts.public = true"
        end

        q.sort_columns = ["posts.version_received_at DESC"]

        q.limit = Feed::DEFAULT_PAGE_LIMIT

        children = q.all

        env['response'] = {
          :versions => children.map { |post| post.version_as_json(:env => env).merge(:type => post.type) }
        }

        if env['params']['profiles']
          env['response'][:profiles] = MetaProfile.new(env['current_user'].id, children).profiles(
            env['params']['profiles'].split(',') & ['entity']
          )
        end

        env['response.headers'] = {}
        env['response.headers']['Content-Type'] = CHILDREN_CONTENT_TYPE

        env
      end
    end

    class ListPostVersions < Middleware
      def action(env)
        ref_post = env.delete('response.post')

        q = Query.new(Model::Post)

        q.query_conditions << "posts.user_id = ?"
        q.query_bindings << env['current_user'].id

        q.query_conditions << "posts.public_id = ?"
        q.query_bindings << ref_post.public_id

        authorizer = Authorizer.new(env)
        if env['current_auth'] && authorizer.auth_candidate
          unless authorizer.auth_candidate.read_all_types?
            _read_type_ids = Model::Type.find_types(authorizer.auth_candidate.read_types).inject({:base => [], :full => []}) do |memo, type|
              if type.fragment.nil?
                memo[:base] << type.id
              else
                memo[:full] << type.id
              end
              memo
            end

            q.query_conditions << ["OR",
              "posts.public = true",
              ["AND",
                "posts.entity_id = ?",
                ["OR",
                  "posts.type_base_id IN ?",
                  "posts.type_id IN ?"
                ]
              ]
            ]
            q.query_bindings << env['current_user'].entity_id
            q.query_bindings << _read_type_ids[:base]
            q.query_bindings << _read_type_ids[:full]
          end
        else
          q.query_conditions << "posts.public = true"
        end

        q.sort_columns = ["posts.version_received_at DESC"]

        q.limit = Feed::DEFAULT_PAGE_LIMIT

        versions = q.all

        env['response'] = {
          :versions => versions.map { |post| post.version_as_json(:env => env).merge(:type => post.type) }
        }

        if env['params']['profiles']
          env['response'][:profiles] = MetaProfile.new(env['current_user'].id, versions).profiles(
            env['params']['profiles'].split(',') & ['entity']
          )
        end

        env['response.headers'] = {}
        env['response.headers']['Content-Type'] = VERSIONS_CONTENT_TYPE

        env
      end
    end

    class GetPost < Middleware
      def action(env)
        params = env['params']

        if params['version'] && params['version'] != 'latest'
          env['response.post'] = post = Model::Post.first(:public_id => params[:post], :entity => params[:entity], :version => params['version'])
        else
          env['response.post'] = post = Model::Post.where(:public_id => params[:post], :entity => params[:entity]).order(Sequel.desc(:version_received_at)).first
        end

        halt!(404, "Not Found") unless post && Authorizer.new(env).read_authorized?(post)

        case env['HTTP_ACCEPT']
        when MENTIONS_CONTENT_TYPE
          return ListPostMentions.new(@app).call(env)
        when CHILDREN_CONTENT_TYPE
          return ListPostChildren.new(@app).call(env)
        when VERSIONS_CONTENT_TYPE
          return ListPostVersions.new(@app).call(env)
        end

        env
      end
    end

    class ServePost < Middleware
      def action(env)
        return env unless Model::Post === (post = env.delete('response.post'))

        params = env['params']

        env['response'] = {
          :post => post.as_json(:env => env)
        }

        if params['max_refs']
          env['response'][:refs] = Refs.fetch(env['current_user'], post, params['max_refs'].to_i).map { |m| m.as_json(:env => env) }
        end

        if params['profiles']
          env['response'][:profiles] = MetaProfile.new(env['current_user'].id, [post]).profiles(params['profiles'].split(','))
        end

        env['response.headers'] ||= {}
        env['response.headers']['Content-Type'] = POST_CONTENT_TYPE % post.type

        env
      end
    end

    class AttachmentRedirect < Middleware
      def action(env)
        unless Model::Post === env['response.post']
          env.delete('response.post')
          return env
        end

        post = env.delete('response.post')
        params = env['params']

        accept = env['HTTP_ACCEPT'].to_s.split(';').first

        attachments = post.attachments.select { |a| a['name'] == params[:name] }

        unless accept == '*/*'
          attachments = attachments.select { |a| a['content_type'] == accept }
        end
        return env if attachments.empty?

        attachment = attachments.first

        attachment_url = Utils.expand_uri_template(env['current_user'].preferred_server['urls']['attachment'],
          :entity => post.entity,
          :digest => attachment['digest']
        )

        (env['response.headers'] ||= {})['Location'] = attachment_url
        env['response.status'] = 302

        env
      end
    end

    class GetAttachment < Middleware
      def action(env)
        params = env['params']

        attachment = Model::Attachment.where(:digest => params[:digest]).first
        halt!(404, "Not Found") unless attachment

        post_attachment = Model::PostsAttachment.where(:attachment_id => attachment.id).first
        halt!(404, "Not Found") unless post_attachment

        post = Model::Post.where(:id => post_attachment.post_id, :user_id => env['current_user'].id).first
        halt!(404, "Not Found") unless post

        if env['current_auth'] && (app_auth = env['current_auth.resource']) && TentType.new(app_auth.type).base == %(https://tent.io/types/app-auth)
          post_type = TentType.new(post.type)
          unless app_auth.content['post_types']['read'].any? { |uri|
            type = TentType.new(uri)
            uri == 'all' || (type.base == post_type.base && (type.has_fragment? ? type.fragment == post_type.fragment : true))
          }
            halt!(404, "Not Found")
          end
        else
          unless post.public
            halt!(404, "Not Found")
          end
        end

        env['response'] = attachment.data.lit
        (env['response.headers'] ||= {})['Content-Length'] = attachment.data.bytesize.to_s
        env['response.headers']['Content-Type'] = post_attachment.content_type
        env
      end
    end

    class CreatePost < Middleware
      def action(env)
        begin
          post = Model::Post.create_from_env(env)
        rescue Model::Post::CreateFailure => e
          halt!(400, e.message)
        end

        env['response.post'] = post

        if %w( https://tent.io/types/app https://tent.io/types/app-auth ).include?(TentType.new(post.type).base) && !env['request.import']
          if TentType.new(post.type).base == "https://tent.io/types/app"
            # app
            credentials_post = Model::Post.first(:id => Model::App.first(:user_id => env['current_user'].id, :post_id => post.id).credentials_post_id)
          else
            # app-auth
            credentials_post = Model::Post.qualify.join(:mentions, :posts__id => :mentions__post_id).where(
              :mentions__post => post.public_id,
              :posts__type_id => Model::Type.find_or_create_full('https://tent.io/types/credentials/v0#').id
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
    end

    class CreatePostVersion < Middleware
      def action(env)
        if env['request.notification']
          case env['request.type'].to_s
          when "https://tent.io/types/relationship/v0#initial"
            RelationshipInitialization.call(env)
          else
            NotificationImporter.call(env)
          end
        else
          unless Authorizer.new(env).write_authorized?(env['data']['entity'], env['data']['type'])
            if env['current_auth']
              halt!(403, "Unauthorized")
            else
              halt!(401, "Unauthorized")
            end
          end

          begin
            env['response.post'] = Model::Post.create_version_from_env(env)
          rescue Model::Post::CreateFailure => e
            halt!(400, e.message)
          end
        end

        env
      end
    end

    class PostsFeed < Middleware
      def action(env)
        feed = Feed.new(env)
        env['response'] = feed

        if env['REQUEST_METHOD'] == 'HEAD'
          env['response.headers'] ||= {}
          env['response.headers']['Count'] = feed.count.to_s
        end

        env
      end
    end

    match '/' do |b|
      b.use HelloWorld
    end

    options %r{/.*} do |b|
      b.use CorsPreflight
    end

    post '/posts' do |b|
      b.use ValidatePostContentType
      b.use CreatePost
      b.use ServePost
    end

    get '/posts/:entity/:post' do |b|
      b.use GetPost
      b.use ServePost
    end

    put '/posts/:entity/:post' do |b|
      b.use CreatePostVersion
      b.use ServePost
    end

    get '/posts/:entity/:post/attachments/:name' do |b|
      b.use GetPost
      b.use AttachmentRedirect
    end

    get '/attachments/:entity/:digest' do |b|
      b.use GetAttachment
    end

    get '/posts' do |b|
      b.use PostsFeed
    end

    get '/oauth/authorize' do |b|
      b.use OAuth::Authorize
    end

    post '/oauth/token' do |b|
      b.use OAuth::Token
    end

    match %r{/.*} do |b|
      b.use NotFound
    end

  end
end
