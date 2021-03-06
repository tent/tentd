module TentD
  class Authorizer
    module AuthCandidate

      class AppAuth < Base
        def read_types
          @read_types ||= resource.content['types']['read'].to_a
        end

        def read_type?(type_uri)
          return true if read_all_types?
          type_authorized?(type_uri, read_types) || write_type?(type_uri)
        end

        def read_all_types?
          read_types.any? { |t| t == 'all' }
        end

        def read_entity?(entity)
          true
        end

        def write_entity?(entity)
          return true if entity.nil? # entity not included in request body
          return true if resource.content['scopes'].to_a.find { |s| s == 'import' }
          entity == current_user.entity
        end

        def write_post?(post)
          write_type?(post.type)
        end

        def write_types
          resource.content['types']['write'].to_a
        end

        def write_all_types?
          write_types.any? { |t| t == 'all' }
        end

        def write_type?(type_uri)
          return true if write_all_types?
          type_authorized?(type_uri, write_types)
        end

        def scopes
          resource.content['scopes'].to_a
        end

        def has_scope?(scope)
          scopes.include?(scope.to_s)
        end
      end

    end
  end
end
