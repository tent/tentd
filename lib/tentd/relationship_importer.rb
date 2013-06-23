module TentD
  class RelationshipImporter
    RELATIONSHIP_TYPE = TentType.new(%(https://tent.io/types/relationship/v0#)).freeze
    CREDENTIALS_TYPE = TentType.new(%(https://tent.io/types/credentials/v0#)).freeze

    ImportError = Class.new(Model::Post::CreateFailure)

    Results = Struct.new(:post)

    def self.import(current_user, attrs)
      # Case 1 (they initiated)
      # [author:them] relationship#initial
      #   - create relationship (entity => attrs[:entity])
      # [author:them] credentials (mentions ^)
      #   - update relationship with [remote] credentials
      # [author:us] relationship# (mentions relationship#initial ^)
      #   - update relationship with post_id
      # [author:us] credentials (mentions ^)
      #   - update relationship with credentials_post_id
      # [author:them] relationship# (mentions relationship# ^)

      # Case 2 (we initiated)
      # [author:us] relationship#initial
      #   - create relationship with post_id (entity => attrs[:mentions][0]['entity'])
      # [author:us] credentials (mentions ^)
      #   - update relationship with credentials_post_id
      # [author:them] relationship# (mentions relationship#initial ^)
      # [author:them] credentials (mentions ^)
      #   - update relationship with [remote] credentials
      # [author:us] relationship# (mentions relationship# ^)
      #   - update post_id

      new(current_user, attrs).import
    end

    attr_reader :current_user, :attrs, :type, :stage, :target_entity, :target_entity_id, :relationship, :post
    def initialize(current_user, attrs)
      @current_user, @attrs = current_user, attrs
      @type = TentType.new(attrs[:type])
    end

    def import
      determine_stage
      determine_target_entity
      determine_target_entity_id
      create_post
      update_or_create_relationship

      Results.new(post)
    end

    private

    def determine_stage
      if type.base == RELATIONSHIP_TYPE.base
        if type.fragment == 'initial'
          if current_user.entity_id == attrs[:entity_id]
            @stage = :local_initial
          else
            @stage = :remote_initial
          end
        else
          if current_user.entity_id == attrs[:entity_id]
            @stage = :local_final
          else
            @stage = :remote_final
          end
        end
      elsif type.base == CREDENTIALS_TYPE.base
        if current_user.entity_id == attrs[:entity_id]
          @stage = :local_credentials
        else
          @stage = :remote_credentials
        end
      end
    end

    def determine_target_entity
      @target_entity = case stage
      when :local_initial
        mention = attrs[:mentions].first

        unless mention
          raise ImportError.new("Invalid #{attrs[:type].inspect}: Must mention an entity")
        end
        
        mention['entity']
      when :local_credentials
        mention = attrs[:mentions].find { |m|
          TentType.new(m['type']).base == RELATIONSHIP_TYPE.base
        }
        post = Model::Post.where(
          :user_id => current_user.id,
          :entity_id => current_user.entity_id,
          :public_id => mention['post']
        ).first

        unless post
          raise ImportError.new("Mentioned relationship post(#{mention['post'].inspect}) not found")
        end

        mention = post.mentions.find { |m|
          TentType.new(m['type']).base == RELATIONSHIP_TYPE.base
        }

        unless mention
          raise ImportError.new("Mentioned post(#{mention['post'].inspect}) must mention a relationship post")
        end
        
        mention['entity']
      when :local_final
        mention = attrs[:mentions].find { |m|
          TentType.new(m['type']).base == RELATIONSHIP_TYPE.base
        }

        unless mention
          raise ImportError.new("Must mention a relationship post")
        end
        
        mention['entity']
      when :remote_initial
        attrs[:entity]
      when :remote_credentials
        attrs[:entity]
      when :remote_final
        attrs[:entity]
      end
    end

    def determine_target_entity_id
      @target_entity_id = if target_entity == attrs['entity']
        attrs['entity_id']
      else
        Model::Entity.first_or_create(target_entity).id
      end
    end

    def create_post
      @post = Model::Post.create(attrs)
    end

    def relationship_attrs
      _attrs = {
        :entity_id => target_entity_id,
        :entity => target_entity
      }

      case stage
      when :local_initial, :local_final
        _attrs[:post_id] = post.id
        _attrs[:type_id] = post.type_id
      when :local_credentials
        _attrs[:credentials_post_id] = post.id
      when :remote_credentials
        _attrs[:remote_credentials_id] = post.public_id
        _attrs[:remote_credentials] = post.content.merge('id' => post.public_id)
      end

      _attrs
    end

    def update_or_create_relationship
      @relationship = find_and_update_relationship || create_relationship
    end

    def find_and_update_relationship
      if relationship = Model::Relationship.where(
          :user_id => current_user.id, 
          :entity_id => target_entity_id
        ).first

        relationship.update(relationship_attrs)

        relationship
      end
    end

    def create_relationship
      Model::Relationship.create(relationship_attrs.merge(
        :user_id => current_user.id,
        :entity_id => target_entity_id
      ))
    rescue Sequel::UniqueConstraintViolation
      find_and_update_relationship
    end
  end
end
