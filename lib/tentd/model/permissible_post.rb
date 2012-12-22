require 'hashie'

module TentD
  module Model
    module PermissiblePost
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def query_with_public_and_private_types(allowed_post_types, post_types, query_conditions, query_bindings)
          if post_types
            requested_post_types = post_types.split(',').map { |t| TentType.new(URI.unescape(t)) }
            requested_allowed_post_types = requested_post_types.select do |type|
              allowed_post_types.include?('all') ||
              allowed_post_types.include?(type.uri)
            end.map(&:base)
            requested_post_types.map!(&:base)
          end

          if post_types.nil?
            unless allowed_post_types.include?('all')
              if allowed_post_types.any?
                query_conditions << "(#{table_name}.type_base IN ? OR #{table_name}.public = ?)"
                query_bindings << allowed_post_types.map { |t| TentType.new(t).base }
                query_bindings << true
              else
                query_conditions << "#{table_name}.public = ?"
                query_bindings << true
              end
            end
          elsif requested_allowed_post_types.empty?
            query_conditions << "(#{table_name}.type_base IN ? AND #{table_name}.public = ?)"
            query_bindings << requested_post_types
            query_bindings << true
          elsif allowed_post_types.include?('all') || (requested_allowed_post_types & requested_post_types) == requested_post_types
            query_conditions << "#{table_name}.type_base IN ?"
            query_bindings << requested_allowed_post_types
          else
            query_conditions << "(#{table_name}.type_base IN ? OR (#{table_name}.type_base IN ? AND #{table_name}.public = ?))"
            query_bindings << requested_allowed_post_types
            query_bindings << requested_post_types
            query_bindings << true
          end
        end

        def fetch_all(params, current_auth)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)
          return [] if params.has_key?(:since_id) && params.since_id.nil?
          return [] if params.has_key?(:before_id) && params.before_id.nil?

          allowed_post_types = current_auth.post_types
          post_types = params.post_types

          _params = params.dup
          %w(before_id since_id).each { |key| _params.delete(key) }
          super(_params) do |_params, query, query_conditions, query_bindings|
            query_with_public_and_private_types(allowed_post_types, post_types, query_conditions, query_bindings)
            build_common_fetch_posts_query(_params, params, query, query_conditions, query_bindings)

            if params.original
              query_conditions << "#{table_name}.original = ?"
              query_bindings << true
            end
          end
        end

        def fetch_with_permissions(params, current_auth)
          params = Hashie::Mash.new(params) unless params.kind_of?(Hashie::Mash)
          return [] if params.has_key?(:since_id) && params.since_id.nil?
          return [] if params.has_key?(:before_id) && params.before_id.nil?

          _params = params.dup
          %w(before_id since_id).each { |key| _params.delete(key) }
          super(_params, current_auth) do |_params, query, query_conditions, query_bindings|
            build_common_fetch_posts_query(_params, params, query, query_conditions, query_bindings)

            if params.post_types
              params.post_types = parse_array_param(params.post_types)
              if params.post_types.any?
                query_conditions << "#{table_name}.type_base IN ?"
                query_bindings << params.post_types.map { |t| TentType.new(t).base }
              end
            end
          end
        end

        private

        def build_common_fetch_posts_query(_params, params, query, query_conditions, query_bindings)
          if params.post_id
            query_conditions << "#{table_name}.post_id = ?"
            query_bindings << params.post_id
          end

          sort_column = get_sort_column(params)

          if params.since_id
            query_conditions << "(#{table_name}.#{sort_column} >= (SELECT #{sort_column} FROM #{table_name} WHERE id = ?) AND #{table_name}.id != ?)"
            query_bindings << params.since_id
            query_bindings << params.since_id

            _params.since_id = params.since_id
          end

          if params.before_id
            query_conditions << "(#{table_name}.#{sort_column} <= (SELECT #{sort_column} FROM #{table_name} WHERE id = ?) AND #{table_name}.id != ?)"
            query_bindings << params.before_id
            query_bindings << params.before_id
          end

          if params.since_time
            query_conditions << "#{table_name}.#{sort_column} > ?"
            query_bindings << Time.at(params.since_time.to_i)
          end

          if params.before_time
            query_conditions << "#{table_name}.#{sort_column} < ?"
            query_bindings << Time.at(params.before_time.to_i)
          end

          if params.mentioned_post || params.mentioned_entity
            select = query.shift
            query.unshift "INNER JOIN mentions ON mentions.#{mentions_relationship_foreign_key} = #{table_name}.id"
            query.unshift select

            if params.mentioned_entity
              query_conditions << "mentions.entity = ?"
              query_bindings << params.mentioned_entity
            end

            if params.mentioned_post
              query_conditions << "mentions.mentioned_post_id = ?"
              query_bindings << params.mentioned_post
            end
          end

          unless params.return_count
            sort_direction = get_sort_direction(params)
            query << "ORDER BY #{table_name}.#{sort_column} #{sort_direction}"
          end
        end

        def sort_reversed?(params)
          super || (params.since_time && params.order.to_s.downcase != 'asc')
        end

        def get_sort_column(params)
          sort_column = case params['sort_by'].to_s
          when 'published_at'
            'published_at'
          when 'updated_at'
            'updated_at'
          else
            'received_at'
          end
        end

        def parse_array_param(value)
          (value.kind_of?(String) ? value.split(',') : value).map { |url| URI.unescape(url) }
        end

        def mentions_relationship_foreign_key
          all_association_reflections.find { |a| a[:name] == :mentions }[:keys].first
        end
      end
    end
  end
end
