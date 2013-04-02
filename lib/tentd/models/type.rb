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

    end

  end
end
