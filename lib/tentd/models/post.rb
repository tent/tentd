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

      def before_create
        self.public_id ||= TentD::Utils.random_id
        self.version = TentD::Utils.hex_digest(canonical_json)
      end

      def save_version
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

        self.class.create_from_env(env)
      end

      def latest_version
        self.class.where(:public_id => public_id).order(Sequel.desc(:version_published_at)).first
      end

      def after_create
        return if version_parents && version_parents.any? # initial version only

        case TentType.new(type).base
        when 'https://tent.io/types/app'
          app = App.update_or_create_from_post(self)
        end
      end

      def queue_delivery
        return unless deliverable?
        Worker::NotificationDispatch.perform_async(self.id)
      end

      # Determines if notifications should be sent out
      def deliverable?
        self.public || self.permissions_entities.to_a.any? || self.permissions_groups.to_a.any?
      end

      def self.create_from_env(env)
        PostBuilder.create_from_env(env)
      end

      def self.create_version_from_env(env, options = {})
        PostBuilder.create_from_env(env, options.merge(:public_id => env['params']['post']))
      end

      def self.import_notification(env)
        create_version_from_env(env, :notification => true)
      end

      def create_attachments(attachments)
        attachments.each_with_index do |attachment, index|
          data = attachment[:tempfile].read
          attachment[:tempfile].rewind

          PostsAttachment.create(
            :attachment_id => Attachment.find_or_create(
              TentD::Utils::Hash.slice(self.attachments[index], 'digest', 'size').merge(:data => data)
            ).id,
            :post_id => self.id,
            :content_type => attachment[:content_type]
          )
        end
      end

      def create_mentions(mentions)
        mentions.map do |mention|
          mention_attrs = {
            :user_id => self.user_id,
            :post_id => self.id
          }

          if mention['entity']
            mention_attrs[:entity_id] = Entity.first_or_create(mention['entity']).id
            mention_attrs[:entity] = mention['entity']
          else
            mention_attrs[:entity_id] = self.entity_id
            mention_attrs[:entity] = self.entity
          end

          if mention['type']
            mention_attrs[:type_id] = Type.find_or_create_full(mention['type']).id
            mention_attrs[:type] = mention['type']
          end

          mention_attrs[:post] = mention['post'] if mention.has_key?('post')
          mention_attrs[:public] = mention['public'] if mention.has_key?('public')

          Mention.create(mention_attrs)
        end
      end

      def create_version_parents(version_parents)
        version_parents.each do |item|
          item['post'] ||= public_id
          _parent = Post.where(:user_id => self.user_id, :public_id => item['post'], :version => item['version']).first
          Parent.create(
            :post_id => self.id,
            :parent_post_id => _parent ? _parent.id : nil,
            :version => item['version'],
            :post => item['post']
          )
        end
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

        if obj[:parents]
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
        end

        attrs
      end

      def canonical_json
        TentCanonicalJson.encode(as_json)
      end

    end

  end
end
