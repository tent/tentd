require 'tent-schemas'
require 'tent-validator'

module TentD
  class SchemaValidator < TentValidator::ResponseExpectation::SchemaValidator

    @schemas = TentSchemas.schemas.inject(Hash.new) do |memo, (name, schema)|
      memo[name] = TentSchemas.inject_refs!(schema)
      memo
    end

    def self.validate(type_uri, data)
      type = TentClient::TentType.new(type_uri)
      schema_name = "post_#{type.base.split('/').last}"

      # Don't validate content of unknown post types
      return unless schema = @schemas[schema_name]

      # Validate content of known post types
      new(schema, "/content").valid?(data)
    end

    def valid?(data)
      diff(data, failed_assertions(data)).empty?
    end

  end
end
