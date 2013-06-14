module TentD

  class Authorizer

    require 'tentd/authorizer/auth_candidate'

    attr_reader :env
    def initialize(env)
      @env = env
    end

    def auth_candidate
      return unless env['current_auth.resource']

      AuthCandidate.new(env['current_user'], env['current_auth.resource'])
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
      return false unless auth_candidate

      auth_candidate.read_type?(post.type) || auth_candidate.read_post?(post)
    end

    def write_authorized?(entity, post_type)
      return false unless env['current_auth']

      # Private server credentials have full authorization
      return true if env['current_auth'][:credentials_resource] == env['current_user']

      # Credentials aren't linked to a valid resource
      return false unless auth_candidate

      auth_candidate.write_entity?(entity) && auth_candidate.write_type?(post_type)
    end
  end

end
