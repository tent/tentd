module TentD
  module Model

    class Type < Sequel::Model(TentD.database[:types])

      def self.first_or_create(type_uri, options = {})
        tent_type = TentClient::TentType.new(type_uri)
        q = options[:select] ? select(*Array(options[:select])) : where

        unless type = q.where(:type => tent_type.to_s).first
          type = create(
            :type => tent_type.to_s,
            :base => tent_type.base,
            :version => tent_type.version,
            :fragment => tent_type.fragment
          )
        end
        type
      end

      def self.fetch_or_create(type_uris, options = {})
        tent_types = type_uris.compact.map { |uri| TentType.new(uri) }
        q = options[:select] ? select(*Array(options[:select])) : where

        types = q.where(:type => tent_types.map(&:to_s)).all

        tent_types.select { |tent_type| !types.any? { |t| t.type == tent_type.to_s } }.each do |tent_type|
          next unless tent_type.base # i.e. "all"
          types << create(
            :type => tent_type.to_s,
            :base => tent_type.base,
            :version => tent_type.version,
            :fragment => tent_type.fragment
          )
        end

        types
      end

    end

  end
end
