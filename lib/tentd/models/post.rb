require 'openssl'
require 'tent-canonical-json'

module TentD
  module Model

    class Post < Sequel::Model(TentD.database[:posts])
      plugin :serialization
      serialize_attributes :pg_array, :permissions_entities, :permissions_groups
      serialize_attributes :json, :mentions, :attachments, :version_parents, :licenses, :content

      def before_create
        self.version = generate_version_signature
      end

      def self.create_from_env(env)
        data = env['data']
        current_user = env['current_user']
        type = Type.first_or_create(data['type'])

        create(
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :entity => current_user.entity,

          :type => type.type,
          :type_id => type.id,
          :type_fragment_id => type.fragment ? type.id : nil,

          :published_at => data['published_at'] ? data['published_at'].to_i : (Time.now.to_f * 1000).to_i,

          :content => data['content'],
        )
      end

      def as_json(options = {})
        {
          :type => self.type,
          :content => self.content,
        }
      end

      private

      def generate_version_signature
        OpenSSL::Digest::SHA512.new.hexdigest(canonical_json).byteslice(0, 32).unpack("H*").first
      end

      def canonical_json
        TentCanonicalJson.encode(as_json)
      end

    end

  end
end
