module TentD
  module Model
    module TypeProperties
      def self.included(base)
        base.class_eval do
         # validates_with_block :type_version do
         #   return true if type_base == 'all' || type_version
         #   [false, 'type version must be set']
         # end
        end
      end

      def validate
        super
        if type_base != 'all' && !type_version
          errors.add(:type_version, 'type version must be set')
        end
      end                            

      def type
        TentType.new.tap do |t|
          t.base = type_base
          t.version = type_version
          t.view = type_view
        end
      end

      def type=(new_t)
        if String === new_t
          new_t = TentType.new(new_t)
        end

        self.type_base = new_t.base
        self.type_version = new_t.version
        self.type_view = new_t.view
      end
    end
  end
end
