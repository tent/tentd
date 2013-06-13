module TentD

  class Authorizer

    class AuthCandidate
      attr_reader :resource
      def initialize(resource)
        @resource = resource
      end

      def read_types
        @read_types ||= begin
          case TentType.new(resource.type).base
          when %(https://tent.io/types/app-auth)
            resource.content['post_types']['read'].to_a
          else
            []
          end
        end
      end

      def read_type?(type_uri)
        return true if read_all_types?

        read_types.any? do |authorized_type_uri|
          break true if authorized_type_uri == type_uri

          authorized_type = TentType.new(authorized_type_uri)
          type = TentType.new(type_uri)

          break true if !authorized_type.has_fragment? && authorized_type.base == type.base

          authorized_type.base == type.base && authorized_type.fragment == type.fragment
        end
      end

      def read_post?(post)
        case TentType.new(resource.type).base
        when %(https://tent.io/types/relationship)
          post == resource
        else
          false
        end
      end

      def read_all_types?
        read_types.any? { |t| t == 'all' }
      end
    end

    attr_reader :env
    def initialize(env)
      @env = env
    end

    def auth_candidate
      return unless env['current_auth.resource']

      AuthCandidate.new(env['current_auth.resource'])
    end

    def app?
      return false unless env['current_auth']

      # Private server credentials have same permissions as fully authorized app
      return true if env['current_auth'][:credentials_resource] == env['current_user']

      return false unless resource = env['current_auth.resource']

      TentType.new(resource.type).base == %(https://tent.io/types/app-auth)
    end

    def read_authorized?(post)
      return true if post.public
      return false unless env['current_auth']

      # Private server credentials have full authorization
      return true if env['current_auth'][:credentials_resource] == env['current_user']

      # Credentials aren't linked to a valid resource
      return false unless resource = env['current_auth.resource']

      auth_candidate.read_type?(post.type) || auth_candidate.read_post?(post)
    end
  end

end
