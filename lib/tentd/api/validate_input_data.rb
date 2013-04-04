require 'tentd/schema_validator'

module TentD
  class API

    class ValidateInputData < Middleware
      def action(env)
        if Hash === env['data']
          validate_data!(env)
        end

        env
      end

      private

      def validate_data!(env)
        invalid_attributes! unless Hash === env['data']['content']

        env['data_valid'] = SchemaValidator.validate(env['data']['type'], env['data'])
        invalid_attributes! if env['data_valid'] == false
      end
    end

  end
end
