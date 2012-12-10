module TentD
  module Model
    module PermissibleProfileInfo
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def fetch_with_permissions(params, current_auth)
          super do |params, query, query_bindings|
            if params.type_base
              query << "AND type_base IN(?)"
              query_bindings << Array(params.type_base)
            end
          end
        end
      end
    end
  end
end
