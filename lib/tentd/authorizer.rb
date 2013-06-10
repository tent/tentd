module TentD

  class Authorizer
    attr_reader :env
    def initialize(env)
      @env = env
    end

    def read_authorized?(post)
      return true if post.public
      return false unless env['current_auth']

      # Private server credentials have full authorization
      return true if env['current_auth'][:credentials_resource] == env['current_user']

      # Credentials aren't linked to a valid resource
      return false unless resource = env['current_auth.resource']

      case TentType.new(resource.type).base
      when %(https://tent.io/types/app)
        return false
      when %(https://tent.io/types/app-auth)
        return resource.content['post_types']['read'].to_a.any? do |read_type_uri|
          read_type_uri == 'all' || types_match?(read_type_uri, post.type)
        end
      when %(https://tent.io/types/relationship)
        return false
      else
        return false
      end
    end

    private

    def types_match?(authorized_type_uri, post_type_uri)
      return true if authorized_type_uri == post_type_uri

      authorized_type = TentType.new(authorized_type_uri)
      post_type = TentType.new(post_type_uri)

      return true if !authorized_type.has_fragment? && authorized_type.base == post_type.base

      authorized_type.base == post_type.base && authorized_type.fragment == post_type.fragment
    end
  end

end
