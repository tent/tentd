module TentD
  module Model

    class Type < Sequel::Model(TentD.database[:types])
      def self.find_or_create(type_uri)
        base_type = find_or_create_base(type_uri)
        full_type = find_or_create_full(type_uri)

        [full_type, base_type]
      end

      def self.find_types(type_uris)
        return [] if type_uris.empty?

        tent_types = type_uris.map { |uri| TentType.new(uri) }
        tent_types_without_fragment = tent_types.select { |t| !t.has_fragment? }
        tent_types_with_fragment = tent_types.select { |t| t.has_fragment? }

        q = Query.new(Type)

        _conditions = ["OR"]

        if tent_types_without_fragment.any?
          _conditions << ["AND",
            "base IN ?",
            "fragment IS NULL"
          ]
          q.query_bindings << tent_types_without_fragment.map(&:base)
        end

        tent_types_with_fragment.each do |tent_type|
          _conditions << ["AND",
            "base = ?",
            "fragment = ?"
          ]
          q.query_bindings << tent_type.base
          q.query_bindings << tent_type.fragment.to_s
        end

        q.query_conditions << _conditions

        types = q.all.to_a
      end

      def self.find_or_create_types(type_uris)
        tent_types = type_uris.map { |uri| TentType.new(uri) }

        types = find_types(type_uris)

        missing_tent_types = tent_types.reject do |tent_type|
          types.any? { |t| tent_type == t.tent_type }
        end

        missing_tent_types.each do |tent_type|
          types << find_or_create_full(tent_type.to_s)
        end

        types.compact
      end

      def self.find_or_create_base(type_uri)
        tent_type = TentClient::TentType.new(type_uri)

        return unless tent_type.base

        unless base_type = where(:base => tent_type.base, :fragment => nil, :version => tent_type.version).first
          begin
            base_type = create(
              :base => tent_type.base,
              :version => tent_type.version,
              :fragment => nil
            )
          rescue Sequel::UniqueConstraintViolation
            type = where(:base => tent_type.base, :fragment => nil, :version => tent_type.version).first
          end
        end

        base_type
      end

      def self.find_or_create_full(type_uri)
        tent_type = TentClient::TentType.new(type_uri)
        fragment = tent_type.has_fragment? ? tent_type.fragment.to_s : nil

        return unless tent_type.base

        unless type = where(:base => tent_type.base, :fragment => fragment, :version => tent_type.version).first
          begin
            type = create(
              :base => tent_type.base,
              :version => tent_type.version,
              :fragment => fragment
            )
          rescue Sequel::UniqueConstraintViolation
            type = where(:base => tent_type.base, :fragment => fragment, :version => tent_type.version).first
          end
        end

        type
      end

      def tent_type
        t = TentType.new
        t.base = self.base
        t.version = self.version
        t.fragment = self.fragment.to_s unless self.fragment.nil?
        t
      end

      def type
        tent_type.to_s
      end

    end

  end
end
