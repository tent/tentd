module TentD
  class Authorizer
    module AuthCandidate

      class App < Base
        def read_post?(post)
          post == resource
        end

        def write_post?(post)
          post == resource
        end

        def write_post_id?(entity, public_id, type_uri)
          entity == resource.entity && public_id == resource.public_id && type_uri == resource.type
        end
      end

    end
  end
end
