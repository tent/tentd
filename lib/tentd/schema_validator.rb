require 'tent-schemas'
require 'api-validator'
require 'tentd/schema_validator/format_validators'

module TentD
  class SchemaValidator < ApiValidator::JsonSchema

    @schemas = TentSchemas.schemas.inject(Hash.new) do |memo, (name, schema)|
      memo[name] = TentSchemas.inject_refs!(schema)
      memo
    end

    def self.validation(type_uri, data)
      type = TentClient::TentType.new(type_uri)
      schema_name = "post_#{type.base.to_s.split('/').last}"

      remove_null_members(data)

      # Validate post schema
      schema = @schemas['post'].dup
      schema['properties'].each_pair { |name, property| property['required'] = false }
      v = new(schema)
      return v unless v.valid?(data)

      # Don't validate content of unknown post types
      return v unless schema = @schemas[schema_name]

      # Validate content of known post types
      new(schema, "/content")
    end

    def self.diff(type_uri, data)
      v = validation(type_uri, data)
      v.diff(data, v.failed_assertions(data))
    end

    def self.validate(type_uri, data)
      diff(type_uri, data).empty?
    end

    def valid?(data)
      diff(data, failed_assertions(data)).empty?
    end

    private

    def self.remove_null_members(hash)
      hash.each_pair do |key, val|
        case val
        when Hash
          remove_null_members(val)
        when Array
          val.each do |item|
            next unless Hash === item
            remove_null_members(item)
          end
        when NilClass
          hash.delete(key)
        end
      end
    end

  end
end
