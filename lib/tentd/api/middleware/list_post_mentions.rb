module TentD
  class API

    class ListPostMentions < Middleware
      def action(env)
        ref_post = env.delete('response.post')

        q = Query.new(Model::Post)
        q.deleted_at_table_names = %w( posts mentions )

        q.select_columns = %w( posts.entity posts.entity_id posts.public_id posts.type mentions.public )

        q.query_conditions << "posts.user_id = ?"
        q.query_bindings << env['current_user'].id

        q.join("INNER JOIN mentions ON mentions.post_id = posts.id")

        q.query_conditions << "mentions.post = ?"
        q.query_bindings << ref_post.public_id

        if env['current_auth'] && (auth_candidate = Authorizer::AuthCandidate.new(env['current_user'], env['current_auth.resource'])) && auth_candidate.read_type?(ref_post.type)
          q.query_conditions << "(mentions.public = true OR posts.entity_id = ?)"
          q.query_bindings << env['current_user'].entity_id
        else
          q.query_conditions << "mentions.public = true"
        end

        q.sort_columns = ["posts.received_at DESC"]

        q.limit = Feed::DEFAULT_PAGE_LIMIT

        posts = q.all

        env['response'] = {
          :mentions => posts.map { |post|
            m = { :type => post.type, :post => post.public_id }
            m[:entity] = post.entity unless ref_post.entity == post.entity
            m[:public] = false if post.public == false
            m
          }
        }

        if env['params']['profiles']
          env['response'][:profiles] = MetaProfile.new(env, posts).profiles(
            env['params']['profiles'].split(',') & ['entity']
          )
        end

        env['response.headers'] = {}
        env['response.headers']['Content-Type'] = MENTIONS_CONTENT_TYPE

        if env['REQUEST_METHOD'] == 'HEAD'
          env['response.headers']['Count'] = q.count.to_s
        end

        env
      end
    end

  end
end
