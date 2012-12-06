require 'hashie'

module TentD
  module Model
    module PermissiblePostVersion
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def fetch_all(params, current_auth)
          params = slice_params(params)

          super(params) do |params, query, query_conditions, query_bindings|
            if params.since_version
              query_conditions << "#{table_name}.version > ?"
              query_bindings << params.since_version
            end

            if params.before_version
              query_conditions << "#{table_name}.version < ?"
              query_bindings << params.before_version
            end

            unless params.return_count
              sort_direction = get_sort_direction(params)
              query << "ORDER BY #{table_name}.version #{sort_direction}"
            end
          end
        end

        def fetch_with_permissions(params, current_auth)
          params = slice_params(params)

          super(params, current_auth) do |params, query, query_bindings|
            if params.since_version
              query << "AND #{table_name}.version > ?"
              query_bindings << params.since_version
            end

            if params.before_version
              query << "AND #{table_name}.version < ?"
              query_bindings << params.before_version
            end

            unless params.return_count
              sort_direction = get_sort_direction(params)
              query << "ORDER BY #{table_name}.version #{sort_direction}"
            end
          end
        end

        def slice_params(params)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)
          params.slice(:before_version, :since_version, :limit, :return_count, :order)
        end
      end
    end
  end
end
