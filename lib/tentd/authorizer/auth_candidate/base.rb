module TentD
  class Authorizer
    module AuthCandidate

      class Base
        attr_reader :current_user, :resource
        def initialize(current_user, resource)
          @current_user, @resource = current_user, resource
        end

        def read_types
          []
        end

        def read_type?(type_uri)
          false
        end

        def read_post?(post)
          false
        end

        def read_all_types?
          false
        end

        def write_types
          []
        end

        def write_type?(type_uri)
          false
        end

        def write_post?(post)
          false
        end

        def write_all_types?
          false
        end

        def write_entity?(entity_uri)
          false
        end

        private

        def type_authorized?(type_uri, authorized_type_uris)
          type = TentType.new(type_uri)
          authorized_type_uris.any? do |authorized_type_uri|
            break true if authorized_type_uri == type_uri

            authorized_type = TentType.new(authorized_type_uri)

            break true if !authorized_type.has_fragment? && authorized_type.base == type.base

            authorized_type.base == type.base && authorized_type.fragment == type.fragment
          end
        end
      end

    end
  end
end
