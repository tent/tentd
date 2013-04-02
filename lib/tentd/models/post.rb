require 'securerandom'
require 'openssl'
require 'tent-canonical-json'

module TentD
  module Model

    class Post < Sequel::Model(TentD.database[:posts])
      plugin :serialization
      serialize_attributes :pg_array, :permissions_entities, :permissions_groups
      serialize_attributes :json, :mentions, :attachments, :version_parents, :licenses, :content

      def before_create
        self.public_id = generate_public_id
        self.version = generate_version_signature
      end

      def self.create_from_env(env)
        data = env['data']
        current_user = env['current_user']
        type = Type.first_or_create(data['type'])

        published_at_timestamp = data['published_at'] ? data['published_at'].to_i : (Time.now.to_f * 1000).to_i

        create(
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_fragment_id => type.fragment ? type.id : nil,

          :version_published_at => published_at_timestamp,
          :published_at => published_at_timestamp,

          :content => data['content'],
        )
      end

      def as_json(options = {})
        attrs = {
          :id => self.public_id,
          :type => self.type,
          :content => self.content,
          :version => {
            :id => self.version,
            :parents => self.version_parents,
            :message => self.version_message,
            :published_at => self.version_published_at
          }
        }
        attrs[:version].delete(:parents) if attrs[:version][:parents].nil?
        attrs[:version].delete(:message) if attrs[:version][:message].nil?
        attrs
      end

      private

      def generate_public_id
        SecureRandom.urlsafe_base64(16)
      end

      def generate_version_signature
        OpenSSL::Digest::SHA512.new.hexdigest(canonical_json).byteslice(0, 32).unpack("H*").first
      end

      def canonical_json
        TentCanonicalJson.encode(as_json)
      end

    end

  end
end
