module TentD
  module Model
    module PermissibleProfileInfo
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        private

        def build_fetch_params(params, query_conditions, query_bindings)
          if params.type_base
            query_conditions << "type_base IN(?)"
            query_bindings << Array(params.type_base)
          end
        end
      end
    end
  end
end
