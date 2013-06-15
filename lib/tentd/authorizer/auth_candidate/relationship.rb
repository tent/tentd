module TentD
  class Authorizer
    module AuthCandidate

      class Relationship < Base
        def read_post?(post)
          post == resource
        end

        def write_entity?(entity_uri)
          return false unless relationship
          relationship.entity == entity_uri
        end

        def write_type?(type_uri)
          return false unless relationship
          true
        end

        private

        def relationship
          @relationship ||= Model::Relationship.where(:post_id => resource.id).first
        end
      end

    end
  end
end
