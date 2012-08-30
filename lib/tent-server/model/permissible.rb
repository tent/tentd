module TentServer
  module Model
    module Permissible
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def find_with_permissions(id, current_auth, &block)
          query = []
          query_bindings = []

          table_name = storage_names[repository_name]

          query << "SELECT #{table_name}.* FROM #{table_name}"

          if current_auth && current_auth.respond_to?(:permissible_foreign_key)
            query << "LEFT OUTER JOIN permissions ON permissions.#{visibility_permissions_relationship_foreign_key} = #{table_name}.id"
            query << "AND (permissions.#{current_auth.permissible_foreign_key} = ?"
            query_bindings << current_auth.id
            if current_auth.respond_to?(:groups) && current_auth.groups.to_a.any?
              query << "OR permissions.group_id IN ?)"
              query_bindings << current_auth.groups
            else
              query << ")"
            end
            query << "WHERE (public = ? OR permissions.#{visibility_permissions_relationship_foreign_key} = #{table_name}.id)"
            query_bindings << true
          else
            query << "WHERE public = ?"
            query_bindings << true
          end

          query << "AND #{table_name}.id = ?"
          query_bindings << id

          if block_given?
            query, query_bindings = block.call(query, query_bindings)
          end

          query << "LIMIT 1"

          records = find_by_sql([query.join(' '), *query_bindings])
          records.first
        end

        protected

        def permissions_relationship_name
          relationships.map(&:name).include?(:access_permissions) ? :access_permissions : :permissions
        end

        def permissions_relationship_foreign_key
          send(permissions_relationship_name).relationships.first.child_key.first.name
        end

        def visibility_permissions_relationship_foreign_key
          relationships.map(&:name).include?(:visibility_permissions) ? visibility_permissions.relationships.first.child_key.first.name : permissions_relationship_foreign_key
        end
      end
    end
  end
end
