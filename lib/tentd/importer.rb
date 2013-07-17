require 'sequel'
require 'tentd'
require 'set'
require 'logger'
require 'faraday'
require 'nokogiri'

module TentD
  class Importer
    class LegacyTentClient
      MEDIA_TYPE = 'application/vnd.tent.v0+json'.freeze
      PROFILE_REL = 'https://tent.io/rels/profile'.freeze

      def initialize(entity_uri)
        @entity_uri = entity_uri
      end

      def faraday_adapter
        Faraday.default_adapter
      end

      def discover
        Discovery.new(self, @entity_uri).tap { |d| d.perform }
      end

      class Discovery
        attr_accessor :url, :profile_urls, :primary_profile_url, :profile

        def initialize(client, url)
          @client, @url = client, url
        end

        def http
          @http ||= Faraday.new do |f|
            f.response :follow_redirects
            f.adapter *Array(@client.faraday_adapter)
          end
        end

        def perform
          @profile_urls = perform_head_discovery || perform_get_discovery || []
          @profile_urls.map! { |l| l =~ %r{\A/} ? URI.join(url, l).to_s : l }
        end

        def get_profile
          profile_urls.each do |url|
            res = @client.http.get(url)
            if res['Content-Type'].to_s.split(';').first == MEDIA_TYPE
              @profile = res.body
              @primary_profile_url = url
              break
            end
          end
          [@profile, @primary_profile_url.to_s.sub(%r{/profile$}, '')]
        end

        def perform_head_discovery
          perform_header_discovery http.head(url)
        end

        def perform_get_discovery
          res = http.get(url)
          perform_header_discovery(res) || perform_html_discovery(res)
        end

        def perform_header_discovery(res)
          if header = res['Link']
            links = TentClient::LinkHeader.parse(header).links.select { |l| l[:rel] == PROFILE_REL }.map { |l| l.uri }
            links unless links.empty?
          end
        end

        def perform_html_discovery(res)
          return unless res['Content-Type'].to_s.downcase =~ %r{\Atext/html}
          Nokogiri::HTML(res.body).css(%(link[rel="#{PROFILE_REL}"])).map { |l| l['href'] }
        end
      end
    end

    POST_TYPE_ESSAY    = "https://tent.io/types/post/essay".freeze
    POST_TYPE_STATUS   = "https://tent.io/types/post/status".freeze
    POST_TYPE_REPOST   = "https://tent.io/types/post/repost".freeze
    POST_TYPE_PHOTO    = "https://tent.io/types/post/photo".freeze
    POST_TYPE_BOOKMARK = "http://www.beberlei.de/tent/bookmark".freeze
    POST_TYPE_FAVORITE = "http://www.beberlei.de/tent/favorite".freeze

    POST_TYPES = [
      POST_TYPE_ESSAY,
      POST_TYPE_STATUS,
      POST_TYPE_REPOST,
      POST_TYPE_PHOTO,
      POST_TYPE_BOOKMARK,
      POST_TYPE_FAVORITE
    ].freeze

    PROFILE_TYPE = "https://tent.io/types/info/basic".freeze

    BATCH_SIZE = 1000.freeze

    SUBSCRIPTION_TYPES = %w(
      https://tent.io/types/status/v0
      https://tent.io/types/repost/v0#https://tent.io/types/status/v0
    ).freeze

    def initialize(options = {})
      @export_database_url = options.delete(:export_database_url)
      import_database_url = options.delete(:import_database_url)
      @entity = options.delete(:entity)

      raise ArgumentError.new("Expected :export_database_url option") unless @export_database_url
      raise ArgumentError.new("Expected :import_database_url option") unless import_database_url
      raise ArgumentError.new("Expected :entity option") unless @entity

      TentD.setup!(options.merge(database_url: import_database_url, database_logger: Logger.new('/dev/null')))

      @logfile = options[:logfile] || STDOUT
      @error_logfile = options[:logfile] || STDERR

      # path to file for listing all entities pending the creation of a relationship
      @output_file_path = options[:output_file_path]

      # list of entities to establish relationships with
      @entities = Set.new

      # entity -> 0.2 server urls mapping
      @entities_servers = Hash.new

      # entity -> 0.3 server meta post mapping
      @entities_meta = Hash.new

      # list of entities to subscribe to
      @subscribe_to_entities = Set.new
    end

    def log_subscription_import_failure(entity)
      logger.error("Failed to import subscription to #{entity}")

      output_file do |f|
        f.write(entity)
      end
    end

    def log_relationship_import_failure(entity)
      logger.error("Failed to import relationship with #{entity}")

      output_file do |f|
        f.write(entity)
      end
    end

    def output_file(&block)
      return unless @output_file_path
      File.open(@output_file_path, 'w', &block)
    end

    def logger
      @logger ||= Logger.new(@logfile, @error_logfile)
    end

    def export_database
      @export_database ||= Sequel.connect(@export_database_url)
    end

    def perform
      import_meta
      import_posts
      import_subscriptions
      import_relationships
    end

    private

    # perform 0.3 discovery
    def perform_discovery(entity)
      return @entities_meta[entity] if @entities_meta.has_key?(entity)

      logger.info("Performing 0.3 discovery on #{entity}")

      @entities_meta[entity] = TentClient.new(entity).server_meta_post

      if !@entities_meta[entity]
        if @entities_servers[entity]
          logger.warn("Discovery failed on #{entity}: entity has not upgraded to 0.3")
        else
          logger.warn("Discovery failed on #{entity}")
        end
      end

      @entities_meta[entity]
    end

    # perform 0.2 discovery
    def perform_legacy_discovery(entity)
      return @entities_servers[entity] if @entities_servers[entity]

      logger.info("Performing 0.2 discovery on #{entity}")

      @entities_servers[entity] = LegacyTentClient.new(entity).discover.profile_urls.map { |url| url.sub(%r{/profile}, '') }
    end

    # fetch 0.2 attachment from post
    def fetch_attachment(post, attachment_name, attachment_type)
      server_urls = perform_legacy_discovery(post[:entity])
      return unless server_urls.any?

      res = server_urls.inject(nil) do |memo, server_url|
        url = "#{server_url}/posts/#{URI.encode_www_form_component(post[:entity])}/#{post[:public_id]}/attachments/#{attachment_name}"
        res = Faraday.get(url) do |req|
          req.headers['Accept'] = attachment_type
        end

        if res.status == 200
          break res
        end

        res
      end

      res
    end

    def export(query, bindings, &block)
      export_database[*[query].concat(bindings)].all.each(&block)
    end

    def export_profile(&block)
      query = """
      SELECT content, updated_at
      FROM profile_info
      WHERE type_base = ?
      AND public = true
      ORDER BY updated_at
      LIMIT 1
      """
      bindings = [PROFILE_TYPE]

      export(query, bindings, &block)
    end

    def export_posts(&block)
      posts_count = export_database[:posts].where(deleted_at: nil).count
      num_batches = (posts_count.to_f / BATCH_SIZE).ceil

      (0...num_batches).each do |index|
        query = """
        SELECT id, public_id, type_base, entity, public, original, licenses, content, app_name, app_url, published_at, received_at
        FROM posts
        WHERE deleted_at IS NULL
        AND type_base IN ?
        ORDER BY published_at
        OFFSET ? LIMIT ?
        """
        bindings = [POST_TYPES, index * BATCH_SIZE, BATCH_SIZE]

        export(query, bindings, &block)
      end
    end

    def export_mentions(post_id, &block)
      query = """
      SELECT entity, mentioned_post_id
      FROM mentions
      WHERE post_id = ?
      ORDER BY id ASC
      """
      bindings = [post_id]

      export(query, bindings, &block)
    end

    def export_permissions(post_id, &block)
      query = """
      SELECT COALESCE(f1.entity, f2.entity) entity
      FROM permissions p
      LEFT JOIN followings f1 ON p.following_id = f1.id
      LEFT JOIN followers f2 ON p.follower_access_id = f2.id
      WHERE p.post_id = ?
      """
      bindings = [post_id]

      export(query, bindings, &block)
    end

    def export_attachment(post_id, &block)
      query = """
      SELECT type, category, name, size, data
      FROM post_attachments
      WHERE post_id = ?
      ORDER BY id ASC
      LIMIT 1
      """
      bindings = [post_id]

      export(query, bindings, &block)
    end

    def export_relationships(&block)
      followings_count = export_database[:followings].where(deleted_at: nil).count
      num_batches = (followings_count.to_f / BATCH_SIZE).ceil

      (0...num_batches).each do |index|
        query = """
        SELECT entity, public
        FROM followings
        WHERE deleted_at IS NOT NULL
        AND confirmed = true
        ORDER BY id ASC
        OFFSET ? LIMIT ?
        """
        bindings = [index * BATCH_SIZE, BATCH_SIZE]

        export(query, bindings, &block)
      end
    end

    # 0.2 profile -> 0.3 meta post
    def transpose_profile(profile)
      old_profile = profile && profile[:content] ? Yajl::Parser.parse(profile[:content]) : nil
      old_profile = Hash === old_profile ? TentD::Utils::Hash.symbolize_keys(old_profile) : nil

      meta = {}

      if Hash === old_profile
        meta[:content] = {}
        meta[:content][:profile]= [:name, :location, :website, :bio].inject({}) do |memo, key|
          memo[key] = old_profile[key] if old_profile[key] && old_profile[key] != ""
          memo
        end
      end

      meta
    end

    def build_attachment_digest(post, attachment)
      if attachment[:data]
        digest = TentD::Utils.hex_digest(Base64.decode64(attachment[:data]))
      else
        res = fetch_attachment(post, attachment[:name], attachment[:type])

        return unless res

        unless res.status == 200
          return logger.error("Unable to fetch attachment #{attachment[:name].inspect} from #{post[:entity].inspect}: GET #{res.env[:url].to_s} #{res.status}")
        end

        unless attachment[:size] == res.body.size
          return logger.error("Attachment size mismatch: Expected #{attachment[:size]}, got #{res.body.size}")
        end

        digest = TentD::Utils.hex_digest(res.body)
      end

      digest
    end

    # 0.2 mentions record -> 0.3 mention json
    def transpose_mention(mention, &block)
      return unless mention[:entity]

      new_mention = {
        entity: mention[:entity]
      }
      new_mention[:post] = mention[:mentioned_post_id] if mention[:mentioned_post_id]

      yield(new_mention)
    end

    # 0.2 permissions record -> permissible entities
    def transpose_permission(permission, &block)
      yield(permission[:entity]) if permission[:entity]
    end

    # 0.2 timestamp -> 0.3 timestamp
    def translate_timestamp(timestamp)
      # seconds -> milliseconds
      timestamp.to_i * 1000
    end

    # 0.2 post record -> 0.3 env
    def transpose_post(post, &block)
      if post[:content]
        post[:content] = Yajl::Parser.parse(post[:content])
        post[:content] = Hash === post[:content] ? TentD::Utils::Hash.symbolize_keys(post[:content]) : nil
      end

      env = {
        'current_user' => @user
      }

      new_post = {
        public: !!post[:public],
        published_at: translate_timestamp(post[:published_at]),
        received_at: translate_timestamp(post[:received_at] || post[:published_at])
      }

      if post[:app_name] && post[:app_url]
        new_post[:app] = {
          name: post[:app_name],
          url: post[:app_url]
        }
      end

      if post[:original]
        new_post[:entity] = @entity
      else
        new_post[:entity] = rewrite_entity(post[:entity])

        # add to list of entities to establish a relationship with
        @entities << new_post[:entity]
      end

      new_post[:mentions] = []
      export_mentions(post[:id]) do |mention|
        transpose_mention(mention) do |new_mention|
          new_post[:mentions] << new_mention
        end
      end

      new_post[:permissions] = {}
      export_permissions(post[:id]) do |permission|
        transpose_permission(permission) do |entity|
          new_post[:permissions][:entities] ||= []
          new_post[:permissions][:entities] << entity
        end
      end

      case post[:type_base]
      when POST_TYPE_ESSAY
        # ignore empty posts
        return unless Hash === post[:content]
        return if post[:content][:body].nil? || post[:content][:body] == ""

        new_post[:type] = "https://tent.io/types/essay/v0#"
        new_post[:content] = TentD::Utils::Hash.slice(post[:content], :title, :excerpt, :body)
      when POST_TYPE_STATUS
        # ignore empty posts
        return unless Hash === post[:content]
        return if post[:content][:text].nil? || post[:content][:text] == ""

        new_post[:type] = "https://tent.io/types/status/v0#"

        if new_post[:mentions].any? { |m| m[:post] }
          new_post[:type] += "reply"

          new_post[:refs] = new_post[:mentions].inject([]) do |memo, mention|
            memo << mention if mention[:post]
            memo
          end
        end

        new_post[:content] = {
          text: post[:content][:text]
        }

        if (Hash === post[:content][:location]) && (Array === post[:content][:location][:coordinates])
          lng, lat = post[:content][:location][:coordinates]
          new_post[:content][:location] = {
            longitude: lng,
            latitude: lat
          }
        end
      when POST_TYPE_REPOST
        # ignore empty posts
        return unless Hash === post[:content]
        return if post[:content][:id].nil? || post[:content][:id] == ""
        return if post[:content][:entity].nil? || post[:content][:entity] == ""

        new_post[:type] = "https://tent.io/types/repost/v0#http://tent.io/types/status/v0"

        new_post[:refs] = [{
          type: "https://tent.io/types/status/v0#",
          post: post[:content][:id],
          entity: rewrite_entity(post[:content][:entity])
        }]
        new_post[:mentions] = new_post[:refs]
      when POST_TYPE_PHOTO
        new_post[:type] = "https://tent.io/types/photo/v0#"

        export_attachment(post[:id]) do |attachment|
          attrs = {
            name: attachment[:name],
            category: attachment[:category],
            content_type: attachment[:type],
            digest: build_attachment_digest(post, attachment),
            size: attachment[:size]
          }

          if attrs && attrs[:digest]
            new_post[:attachments] = [attrs]
          end
        end

        return unless new_post[:attachments]
      when POST_TYPE_BOOKMARK
        # ignore empty posts
        return unless Hash === post[:content]
        return if post[:content][:post].nil? || post[:content][:post] == ""
        return if post[:content][:entity].nil? || post[:content][:entity] == ""

        new_post[:type] = POST_TYPE_BOOKMARK + "/v0.0.1#"
        new_post[:content] = post[:content]
      when POST_TYPE_FAVORITE
        # ignore empty posts
        return unless Hash === post[:content]
        return if post[:content][:id].nil? || post[:content][:id] == ""
        return if post[:content][:entity].nil? || post[:content][:entity] == ""

        new_post[:type] = "https://tent.io/types/favorite/v0#https://tent.io/types/status/v0"
        new_post[:refs] = [{
          post: post[:content][:id],
          entity: post[:content][:entity]
        }]
      end

      env['data'] = TentD::Utils::Hash.stringify_keys(new_post)
      yield(env)
    end

    def import_meta
      export_profile do |profile|
        import_meta_post(transpose_profile(profile))
      end
    end

    def import_meta_post(meta_attrs)
      @user = TentD::Model::User.create({entity: @entity}, meta_post_attrs: meta_attrs)
    end

    def import_posts
      export_posts do |post|
        logger.info "Importing Post(type: #{post[:type_base]}, entity: #{post[:entity]})"
        transpose_post(post) do |env|
          import_post(env)
        end
      end
    end

    def import_post(env)
      options = {
        import: true
      }
      options[:notification] = true unless env['data']['entity'] == @entity

      TentD::Model::PostBuilder.create_from_env(env, options)
    rescue TentD::Model::Post::CreateFailure => e
      logger.error "Failed to import Post(type: #{env['data']['type']}, entity: #{env['data']['entity']}, id: #{env['data']['id']}): #{e.inspect}\n\t#{e.backtrace.join("\n\t")}"
    end

    def import_subscriptions
      export_relationships do |following|
        entity = rewrite_entity(following.entity)
        @entities.delete(entity)

        unless meta_post = perform_discovery(entity)
          log_subscription_import_failure(entity)
          break
        end

        SUBSCRIPTION_TYPES.each do |type|
          tent_type = TentType.new(type)

          attrs = {
            type: "https://tent.io/types/subscription/v0##{tent_type.to_s(fragment: false)}",
            content: {
              type: tent_type.to_s
            },
            mentions: [{
              entity: entity
            }],
            permissions: {
              public: following.public
            }
          }

          import_post(
            'current_user' => @user,
            'data' => TentD::Utils::Hash.stringify_keys(attrs)
          )
        end
      end
    end

    def import_relationships
      @entities.each do |entity|
        @entities.delete(entity)

        unless meta_post = perform_discovery(entity)
          log_relationship_import_failure(entity)
          break
        end

        Model::Relationship.create_initial(@user, entity)
      end
    end

    # tent.is is now cupcake.is
    def rewrite_entity(entity)
      if entity == "https://tent.tent.is"
        "https://cupcake.cupcake.is"
      elsif entity.end_with?(".tent.is")
        entity[0..-8] + "cupcake.is"
      else
        entity
      end
    end
  end
end
