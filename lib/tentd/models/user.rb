module TentD
  module Model

    class User < Sequel::Model(TentD.database[:users])
      def self.create(attrs)
        entity = Entity.first_or_create(attrs[:entity])
        super(attrs.merge(:entity_id => entity.id))
      end

      def self.first_or_create(entity_uri)
        first(:entity => entity_uri) || create(:entity => entity_uri)
      end
    end

  end
end
