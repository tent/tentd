require 'hashie'

module TentD
  module Model
    module Permissible
      def self.included(base)
        base.extend(ClassMethods)
      end

      def permissions_json(extended = false)
        if extended
          groups = []
          entities = []
          send(respond_to?(:permissions) ? :permissions : :visibility_permissions).each do |permission|
            groups << permission.group.public_id if permission.group
            entities << permission.follower_access.entity if permission.follower_access
          end

          {
            :groups => groups.uniq,
            :entities => Hash[entities.uniq.map { |e| [e, true] }],
            :public => self.public
          }
        else
          { :public => self.public }
        end
      end

      def assign_permissions(permissions)
        return unless permissions.kind_of?(Hash)

        if permissions.groups && permissions.groups.kind_of?(Array)
          permissions.groups.each do |g|
            next unless g.id
            group = Model::Group.first(:public_id => g.id, :fields => [:id])
            self.permissions.create(:group => group) if group
          end
        end

        if permissions.entities && permissions.entities.kind_of?(Hash)
          permissions.entities.each do |entity,visible|
            next unless visible
            followers = Model::Follower.all(:entity => entity, :fields => [:id])
            followers.each do |follower|
              self.permissions.create(:follower_access => follower)
            end
            followings = Model::Following.all(:entity => entity, :fields => [:id])
            followings.each do |following|
              self.permissions.create(:following => following)
            end
          end
        end
        unless permissions.public.nil?
          self.public = permissions.public
          save
        end
      end

      module ClassMethods
        def query_with_permissions(current_auth, params=Hashie::Mash.new)
          query = []
          query_bindings = []

          if params.return_count
            query << "SELECT COUNT(#{table_name}.*) FROM #{table_name}"
          else
            query << "SELECT #{table_name}.* FROM #{table_name}"
          end

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

          query << "AND user_id = ?"
          query_bindings << User.current.id

          query << "AND #{table_name}.deleted_at IS NULL"

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

        def fetch_all(params, &block)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)

          query = []
          query_conditions = []
          query_bindings = []

          if params.return_count
            query << "SELECT COUNT(#{table_name}.*) FROM #{table_name}"
          else
            query << "SELECT #{table_name}.* FROM #{table_name}"
          end

          if params.since_id
            query_conditions << "#{table_name}.id > ?"
            query_bindings << params.since_id.to_i
          end

          if params.before_id
            query_conditions << "#{table_name}.id < ?"
            query_bindings << params.before_id.to_i
          end

          if params.entity
            query_conditions << "#{table_name}.entity IN ?"
            query_bindings << Array(params.entity)
          end

          if block_given?
            yield params, query, query_conditions, query_bindings
          end

          query_conditions << "#{table_name}.user_id = ?"
          query_bindings << User.current.id

          query_conditions << "#{table_name}.deleted_at IS NULL"

          order_part = query.last =~ /^order/i ? query.pop : nil
          query << "WHERE #{query_conditions.join(' AND ')}"
          query << order_part if order_part

          unless params.return_count
            sort_direction = get_sort_direction(params)
            query << "ORDER BY id #{sort_direction}" unless query.find { |q| q =~ /^order/i }

            query << "LIMIT ?"
            query_bindings << [(params.limit ? params.limit.to_i : TentD::API::PER_PAGE), TentD::API::MAX_PER_PAGE].min
          end

          if params.return_count
            DataMapper.repository(:default).adapter.send(:with_connection) do |connection|
              connection.create_command(query.join(' ')).execute_reader(*query_bindings).to_a.first['count']
            end
          else
            find_by_sql([query.join(' '), *query_bindings])
          end
        end

        def fetch_with_permissions(params, current_auth, &block)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)

          query_with_permissions(current_auth, params) do |query, query_bindings|
            if params.since_id
              query << "AND #{table_name}.id > ?"
              query_bindings << params.since_id.to_i
            end

            if params.before_id
              query << "AND #{table_name}.id < ?"
              query_bindings << params.before_id.to_i
            end

            if params.entity
              query << "AND #{table_name}.entity IN ?"
              query_bindings << Array(params.entity)
            end

            if block_given?
              yield params, query, query_bindings
            end

            unless params.return_count
              sort_direction = get_sort_direction(params)
              query << "ORDER BY id #{sort_direction}" unless query.find { |q| q =~ /^order/i }

              query << "LIMIT ?"
              query_bindings << [(params.limit ? params.limit.to_i : TentD::API::PER_PAGE), TentD::API::MAX_PER_PAGE].min
            end

            if params.return_count
              DataMapper.repository(:default).adapter.send(:with_connection) do |connection|
                connection.create_command(query.join(' ')).execute_reader(*query_bindings).to_a.first['count']
              end
            else
              find_by_sql([query.join(' '), *query_bindings])
            end
          end
        end

        private

        def get_sort_direction(params)
          if params['reverse'].to_s == 'false'
            'ASC'
          else
            'DESC'
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
