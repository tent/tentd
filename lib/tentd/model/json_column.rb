require 'yajl'

module TentD
  module Model
    module JsonColumn
      module Serialize
        def self.call(value)
          return if value.nil?
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
