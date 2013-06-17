require 'tentd/schema_validator'

module TentD
  class API

    class ValidateInputData < Middleware
      def action(env)
        if Hash === env['data'] && [POST_CONTENT_MIME, MULTIPART_CONTENT_MIME].include?(env['request.mime'])
          validate_post!(env)
          validate_attachments!(env)
        end

        env
      end

      private

      def validate_post!(env)
        if env['data'].has_key?('content') && !(Hash === env['data']['content'])
          halt!(400, "Malformed content: #{encode(env['data']['content']).inspect}") 
        end

        unless env['data'].has_key?('type')
          halt!(400, "Type not specified: #{encode(env['data']).inspect}")
        end

        diff = SchemaValidator.diff(env['data']['type'], env['data'])
        if diff.any?
          halt!(400, "Invalid Attributes", :diff => diff)
        end
      end

      def validate_attachments!(env)
        return unless env['attachments']
        halt!(400, "Malformed Request") unless Array === env['attachments']

        env['attachments'].each do |attachment|
          validate_attachment_hash!(attachment)
        end
      end

      def validate_attachment_hash!(attachment)
        return unless attachment[:headers].has_key?(ATTACHMENT_DIGEST_HEADER)

        digest = TentD::Utils.hex_digest(attachment[:tempfile])

        unless digest == attachment[:headers][ATTACHMENT_DIGEST_HEADER]
          halt!(400, "Attachment digest mismatch: #{digest}")
        end
      end

      def encode(data)
        Yajl::Encoder.encode(data)
      end
    end

  end
end
