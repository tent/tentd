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

    require 'tentd/api/middleware'
    require 'tentd/api/middleware/hello_world'
    require 'tentd/api/middleware/not_found'
    require 'tentd/api/middleware/user_lookup'
    require 'tentd/api/middleware/authentication'
    require 'tentd/api/middleware/authorization'
    require 'tentd/api/middleware/parse_input_data'
    require 'tentd/api/middleware/parse_content_type'
    require 'tentd/api/middleware/parse_link_header'
    require 'tentd/api/middleware/validate_input_data'
    require 'tentd/api/middleware/validate_post_content_type'
    require 'tentd/api/middleware/set_request_proxy_manager'
    require 'tentd/api/middleware/proxy_post_list'
    require 'tentd/api/middleware/list_post_mentions'
    require 'tentd/api/middleware/list_post_children'
    require 'tentd/api/middleware/list_post_versions'
    require 'tentd/api/middleware/authorize_get_entity'
    require 'tentd/api/middleware/lookup_post'
    require 'tentd/api/middleware/get_post'
    require 'tentd/api/middleware/serve_post'
    require 'tentd/api/middleware/proxy_attachment_redirect'
    require 'tentd/api/middleware/attachment_redirect'
    require 'tentd/api/middleware/get_attachment'
    require 'tentd/api/middleware/create_post'
    require 'tentd/api/middleware/create_post_version'
    require 'tentd/api/middleware/delete_post'
    require 'tentd/api/middleware/posts_feed'

    require 'tentd/api/serialize_response'
    require 'tentd/api/cors_headers'
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
    middleware SetRequestProxyManager

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
      b.use AuthorizeGetEntity
      b.use ProxyPostList
      b.use LookupPost
      b.use ProxyPostList # lookup failed, proxy_condition is :on_miss
      b.use GetPost
      b.use ServePost
    end

    put '/posts/:entity/:post' do |b|
      b.use CreatePostVersion
      b.use ServePost
    end

    delete '/posts/:entity/:post' do |b|
      b.use LookupPost
      b.use DeletePost
      b.use ServePost
    end

    get '/posts/:entity/:post/attachments/:name' do |b|
      b.use ProxyAttachmentRedirect
      b.use LookupPost
      b.use ProxyAttachmentRedirect # lookup failed, proxy_condition is :on_miss
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
