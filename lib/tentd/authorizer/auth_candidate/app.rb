module TentD
  class Authorizer
    module AuthCandidate

      class App < Base
        def read_post?(post)
          post == resource
        end
      end

    end
  end
end
