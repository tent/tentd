require 'securerandom'
require 'openssl'
require 'tent-canonical-json'

module TentD
  module Model

    class Post < Sequel::Model(TentD.database[:posts])
      CreateFailure = Class.new(StandardError)

      plugin :serialization
      serialize_attributes :pg_array, :permissions_entities, :permissions_groups
      serialize_attributes :json, :mentions, :refs, :attachments, :version_parents, :licenses, :content

      plugin :paranoia if Model.soft_delete

      attr_writer :user

      def before_create
        self.public_id ||= TentD::Utils.random_id
        self.version = TentD::Utils.hex_digest(canonical_json)
        self.received_at ||= TentD::Utils.timestamp
        self.version_received_at ||= TentD::Utils.timestamp
      end

      def save_version(options = {})
        data = as_json
        data[:version] = {
          :parents => [
            { :version => data[:version][:id], :post => data[:id] }
          ]
        }

        env = {
          'data' => TentD::Utils::Hash.stringify_keys(data),
          'current_user' => User.first(:id => user_id)
        }

        self.class.create_from_env(env, options)
      end

      def latest_version
        self.class.where(:public_id => public_id).order(Sequel.desc(:version_published_at)).first
      end

      def around_save
        if (self.changed_columns & [:public]).any?
          if super
            queue_delivery
          end
        else
          super
        end
      end

      def after_destroy
        if TentType.new(self.type).base == %(https://tent.io/types/subscription)
          Subscription.post_destroyed(self)
        end

        super
      end

      def queue_delivery
        return unless deliverable?
        Worker::NotificationDispatch.perform_async(self.id)
      end

      # Determines if notifications should be sent out
      def deliverable?
        return false unless self.entity_id == User.select(:entity_id).where(:id => self.user_id).first.entity_id
        self.public || self.permissions_entities.to_a.any? || self.permissions_groups.to_a.any? || App.subscribers?(self)
      end

      class << self
        alias _create create
        def create(attrs)
          _create(attrs)
        rescue Sequel::UniqueConstraintViolation => e
          params = {
            :user_id => attrs[:user_id],
            :entity_id => attrs[:entity_id],
            :public_id => attrs[:public_id],
            :version => attrs[:version]
          }

          TentD.logger.debug "Post.create: UniqueConstraintViolation" if TentD.settings[:debug]
          TentD.logger.debug "Post.create -> Post.first(#{params.inspect})" if TentD.settings[:debug]

          post = first(params)

          TentD.logger.debug "Post.first => Post(#{post ? post.id : nil.inspect})" if TentD.settings[:debug]

          raise CreateFailure.new("Server Error: #{Yajl::Encoder.encode(params)}") unless post

          post
        end
      end

      def self.create_from_env(env, options = {})
        PostBuilder.create_from_env(env, options)
      end

      def self.create_version_from_env(env, options = {})
        TentD.logger.debug "Post.create_version_from_env" if TentD.settings[:debug]

        PostBuilder.create_from_env(env, options.merge(:public_id => env['params']['post']))
      end

      def self.import_notification(env)
        TentD.logger.debug "Post.import_notification" if TentD.settings[:debug]

        create_version_from_env(env, :notification => true, :entity => env['params']['entity'])
      end

      def destroy(options = {})
        _id = self.id

        _res = if options.delete(:create_delete_post)
          if super(options)
            if options[:delete_version]
              PostBuilder.create_delete_post(self, :version => true)
            else
              PostBuilder.create_delete_post(self)
            end
          else
            false
          end
        else
          super(options)
        end

        if _res && !options[:delete_version]
          # delete all parents and children
          children = Post.qualify.join(:parents, :parents__post_id => :posts__id).where(:parents__parent_post_id => _id).all.to_a
          parents = Post.qualify.join(:parents, :parents__parent_post_id => :posts__id).where(:parents__post_id => _id).all.to_a
          Parent.where(Sequel.|(:post_id => _id, :parent_post_id => _id)).destroy
          children.each { |child| child.destroy(options) }
          parents.each { |child| child.destroy(options) }
        end

        _res
      end

      def user
        @user ||= User.where(:id => self.user_id).first
      end

      def create_attachments(attachments)
        PostBuilder.create_attachments(self, attachments)
      end

      def create_mentions(mentions)
        PostBuilder.create_mentions(self, mentions)
      end

      def create_version_parents(version_parents)
        PostBuilder.create_version_parents(self, version_parents)
      end

      def version_as_json(options = {})
        obj = {
          :id => self.version,
          :parents => self.version_parents,
          :message => self.version_message,
          :published_at => self.version_published_at,
          :received_at => self.version_received_at
        }
        obj.delete(:parents) if obj[:parents].nil?
        obj.delete(:message) if obj[:message].nil?
        obj.delete(:received_at) if obj[:received_at].nil?

        if obj[:parents] && !options[:delivery]
          obj[:parents].each do |parent|
            parent.delete('post') if parent['post'] == self.public_id
          end
        end

        unless (env = options[:env]) && Authorizer.new(env).app?
          obj.delete(:received_at)
        end

        obj
      end

      def as_json(options = {})
        attrs = {
          :id => self.public_id,
          :type => self.type,
          :entity => self.entity,
          :published_at => self.published_at,
          :received_at => self.received_at,
          :content => self.content,
          :mentions => self.mentions,
          :refs => self.refs,
          :version => version_as_json(options)
        }
        attrs.delete(:received_at) if attrs[:received_at].nil?
        attrs.delete(:content) if attrs[:content].nil?
        attrs.delete(:mentions) if attrs[:mentions].nil?
        attrs.delete(:refs) if attrs[:refs].nil?

        unless (env = options[:env]) && Authorizer.new(env).app?
          attrs.delete(:received_at)
          (attrs[:app] || {}).delete(:id)
        end

        if Array(self.attachments).any?
          attrs[:attachments] = self.attachments
        end

        if attrs[:mentions]
          attrs[:mentions].each do |m|
            m.delete('entity') if m['entity'] == self.entity
          end
        end

        if attrs[:refs]
          attrs[:refs].each do |m|
            m.delete('entity') if m['entity'] == self.entity
          end
        end

        if self[:public] == false
          attrs[:permissions] = { :public => false }
          if (env = options[:env]) && Authorizer.new(env).app?
            attrs[:permissions][:entities] = self.permissions_entities if self.permissions_entities.to_a.any?
          end
        end

        attrs
      end

      def canonical_json
        TentCanonicalJson.encode(as_json)
      end

    end

  end
end
