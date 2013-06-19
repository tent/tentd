module TentD
  module Model

    class Entity < Sequel::Model(TentD.database[:entities])
      plugin :paranoia if Model.soft_delete

      def self.first_or_create(entity_uri)
        first(:entity => entity_uri) || create(:entity => entity_uri)
      rescue Sequel::UniqueConstraintViolation
        first(:entity => entity_uri)
      end

    end

  end
end
