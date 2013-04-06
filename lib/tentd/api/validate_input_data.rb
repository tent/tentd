require 'tentd/schema_validator'

module TentD
  class API

    class ValidateInputData < Middleware
      def action(env)
        if Hash === env['data']
          validate_post!(env)
          validate_attachments!(env)
        end

        env
      end

      private

      def validate_post!(env)
        invalid_attributes! unless Hash === env['data']['content']

        env['data.valid?'] = SchemaValidator.validate(env['data']['type'], env['data'])
        invalid_attributes! if env['data.valid?'] == false
      end

      def validate_attachments!(env)
        return unless env['attachments']
        invalid_attributes! unless Array === env['attachments']

        env['attachments'].each do |attachment|
          validate_attachment_hash!(attachment)
        end
      end

      def validate_attachment_hash!(attachment)
        return unless attachment[:headers].has_key?(ATTACHMENT_DIGEST_HEADER)

        digest = TentD::Utils.hex_digest(attachment[:tempfile])
        invalid_attributes! unless digest == attachment[:headers][ATTACHMENT_DIGEST_HEADER]
      end
    end

  end
end
