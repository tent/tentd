require 'yajl'

module TentD
  module Model
    module JsonColumn
      module Serialize
        def self.call(value)
          return value if value.nil? || value.kind_of?(String)
          Yajl::Encoder.encode(value)
        end
      end

      module Deserialize
        def self.call(value)
          return if value.nil?
          Yajl::Parser.parse(value)
        end
      end
    end
  end
end
