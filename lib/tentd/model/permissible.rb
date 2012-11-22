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
            next unless group = Group.select(:id).first(:user_id => User.current.id, :public_id => g.id)
            Permission.create(
              self.class.send(:permissions_relationship_foreign_key) => self.id,
              :group => group
            )
          end
        end

        if permissions.entities && permissions.entities.kind_of?(Hash)
          permissions.entities.each do |entity,visible|
            next unless visible
            followers = Follower.select(:id).where(:user_id => User.current.id, :entity => entity).all
            followers.each do |follower|
              Permission.create(
                self.class.send(:permissions_relationship_foreign_key) => self.id,
                :follower_access => follower
              )
            end
            followings = Following.select(:id).where(:user_id => User.current.id, :entity => entity).all
            followings.each do |following|
              Permission.create(
                self.class.send(:permissions_relationship_foreign_key) => self.id,
                :following => following
              )
            end
          end
        end
        unless permissions.public.nil?
          self.public = permissions.public
          save
        end
      end

      def visibility_permissions_relationship_name
        self.class.associations.include?(:visibility_permissions) ? :visibility_permissions : :permissions
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

          if columns.include?(:original)
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

            with_sql(query.join(' '), *query_bindings).first
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

          return [] if params.has_key?(:since_id) && params.since_id.nil?
          return [] if params.has_key?(:before_id) && params.before_id.nil?

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
            with_sql(query.join(' '), *query_bindings).all.first[:count]
          else
            with_sql(query.join(' '), *query_bindings).all
          end
        end

        def fetch_with_permissions(params, current_auth, &block)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)

          query_with_permissions(current_auth, params) do |query, query_bindings|
            return [] if params.has_key?(:since_id) && params.since_id.nil?
            return [] if params.has_key?(:before_id) && params.before_id.nil?

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
              with_sql(query.join(' '), *query_bindings).all.first[:count]
            else
              with_sql(query.join(' '), *query_bindings).all
            end
          end
        end

        private

        def get_sort_direction(params)
          if params['order'].to_s.downcase == 'asc'
            'ASC'
          else
            'DESC'
          end
        end

        def permissions_relationship_name
          associations.include?(:access_permissions) ? :access_permissions : :permissions
        end

        def permissions_relationship_foreign_key
          all_association_reflections.find { |a| a[:name] == permissions_relationship_name }[:keys].first
        end

        def visibility_permissions_relationship_foreign_key
          if associations.include?(:visibility_permissions)
            all_association_reflections.find { |a| a[:name] == :visibility_permissions }[:keys].first
          else
            permissions_relationship_foreign_key
          end
        end
      end
    end
  end
end
