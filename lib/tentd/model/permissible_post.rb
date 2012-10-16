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
          allowed_post_types = current_auth.post_types
          post_types = params.post_types
          super(params) do |params, query, query_conditions, query_bindings|
            query_with_public_and_private_types(allowed_post_types, post_types, query_conditions, query_bindings)

            if params.post_id
              query_conditions << "#{table_name}.post_id = ?"
              query_bindings << params.post_id
            end

            if params.since_time
              query_conditions << "#{table_name}.received_at > ?"
              query_bindings << Time.at(params.since_time.to_i)
            end

            if params.before_time
              query_conditions << "#{table_name}.received_at < ?"
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

            if params.original
              query_conditions << "#{table_name}.original = ?"
              query_bindings << true
            end

            unless params.return_count
              query << "ORDER BY #{table_name}.received_at DESC"
            end
          end
        end

        def fetch_with_permissions(params, current_auth)
          super do |params, query, query_bindings|
            if params.post_id
              query << "AND #{table_name}.post_id = ?"
              query_bindings << params.post_id
            end

            if params.since_time
              query << "AND #{table_name}.received_at > ?"
              query_bindings << Time.at(params.since_time.to_i)
            end

            if params.before_time
              query << "AND #{table_name}.received_at < ?"
              query_bindings << Time.at(params.before_time.to_i)
            end

            if params.post_types
              params.post_types = params.post_types.split(',').map { |url| URI.unescape(url) }
              if params.post_types.any?
                query << "AND #{table_name}.type_base IN ?"
                query_bindings << params.post_types.map { |t| TentType.new(t).base }
              end
            end

            if params.mentioned_post || params.mentioned_entity
              select = query.shift
              query.unshift "INNER JOIN mentions ON mentions.#{mentions_relationship_foreign_key} = #{table_name}.id"
              query.unshift select

              if params.mentioned_entity
                query << "AND mentions.entity = ?"
                query_bindings << params.mentioned_entity
              end

              if params.mentioned_post
                query << "AND mentions.mentioned_post_id = ?"
                query_bindings << params.mentioned_post
              end
            end

            unless params.return_count
              query << "ORDER BY #{table_name}.received_at DESC"
            end
          end
        end

        def mentions_relationship_foreign_key
          mentions.relationships.first.child_key.first.name
        end
      end
    end
  end
end
