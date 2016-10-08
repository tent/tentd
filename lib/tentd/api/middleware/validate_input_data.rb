require 'tentd/schema_validator'

module TentD
  class API

    class ValidateInputData < Middleware
      def action(env)
        TentD.logger.debug "ValidateInputData#action" if TentD.settings[:debug]

        if Hash === env['data'] && [POST_CONTENT_MIME, MULTIPART_CONTENT_MIME].include?(env['request.mime'])
          validate_post!(env)
          validate_attachments!(env)
        end

        TentD.logger.debug "ValidateInputData#action complete" if TentD.settings[:debug]

        env
      end

      private

      def validate_post!(env)
        if env['data'].has_key?('content') && !(Hash === env['data']['content'])
          err = encode(env['data']['content']).inspect

          TentD.logger.debug "ValidateInputData Malformed content: #{err}" if TentD.settings[:debug]

          halt!(400, "Malformed content: #{err}") 
        end

        unless env['data'].has_key?('type')
          err = encode(env['data']).inspect

          TentD.logger.debug "ValidateInputData type not specified: #{err}" if TentD.settings[:debug]

          halt!(400, "Type not specified: #{err}")
        end

        diff = SchemaValidator.diff(env['data']['type'], env['data'])
        if diff.any?
          TentD.logger.debug "ValidateInputData Invalid Attributes: #{diff}" if TentD.settings[:debug]

          halt!(400, "Invalid Attributes", :diff => diff)
        end
      end

      def validate_attachments!(env)
        return unless env['attachments']

        TentD.logger.debug "ValidateInputData Malformed Request: env['attachments'] expected to be an array, got an instance of #{env['attachments'].class.name} instead" if TentD.settings[:debug]

        halt!(400, "Malformed Request") unless Array === env['attachments']
      end

      def encode(data)
        Yajl::Encoder.encode(data)
      end
    end

  end
end
