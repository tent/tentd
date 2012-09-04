require 'hashie'

module TentD
  module Model
    module Permissible
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def query_with_permissions(current_auth)
          query = []
          query_bindings = []

          query << "SELECT #{table_name}.* FROM #{table_name}"

          if current_auth && current_auth.respond_to?(:permissible_foreign_key)
            query << "LEFT OUTER JOIN permissions ON permissions.#{visibility_permissions_relationship_foreign_key} = #{table_name}.id"
            query << "AND (permissions.#{current_auth.permissible_foreign_key} = ?"
            query_bindings << current_auth.id
            if current_auth.respond_to?(:groups) && current_auth.groups.to_a.any?
              query << "OR permissions.group_public_id IN ?)"
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

          if properties[:original]
            query << "AND original = ?"
            query_bindings << true
          end

          if block_given?
            yield query, query_bindings
          end
        end

        def find_with_permissions(id, current_auth)
          query_with_permissions(current_auth) do |query, query_bindings|
            query << "AND #{table_name}.id = ?"
            query_bindings << id

            query << "LIMIT 1"

            records = find_by_sql([query.join(' '), *query_bindings])
            records.first
          end
        end

        def fetch_all(params)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)

          query = []
          query_conditions = []
          query_bindings = []

          query << "SELECT #{table_name}.* FROM #{table_name}"
          if params.since_id
            query_conditions << "#{table_name}.id > ?"
            query_bindings << params.since_id.to_i
          end

          if params.before_id
            query_conditions << "#{table_name}.id < ?"
            query_bindings << params.before_id.to_i
          end

          if block_given?
            yield params, query_conditions, query_bindings
          end

          if query_conditions.any?
            query << "WHERE #{query_conditions.join(' AND ')}"
          end

          query << "LIMIT ?"
          query_bindings << [(params.limit ? params.limit.to_i : TentD::API::PER_PAGE), TentD::API::MAX_PER_PAGE].min

          find_by_sql([query.join(' '), *query_bindings])
        end

        def fetch_with_permissions(params, current_auth, &block)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)

          query_with_permissions(current_auth) do |query, query_bindings|
            if params.since_id
              query << "AND #{table_name}.id > ?"
              query_bindings << params.since_id.to_i
            end

            if params.before_id
              query << "AND #{table_name}.id < ?"
              query_bindings << params.before_id.to_i
            end

            if block_given?
              yield params, query, query_bindings
            end

            query << "LIMIT ?"
            query_bindings << [(params.limit ? params.limit.to_i : TentD::API::PER_PAGE), TentD::API::MAX_PER_PAGE].min

            find_by_sql([query.join(' '), *query_bindings])
          end
        end

        protected

        def table_name
          storage_names[repository_name]
        end

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
