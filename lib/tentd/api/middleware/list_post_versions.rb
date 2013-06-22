module TentD
  class API

    class ListPostVersions < Middleware
      def action(env)
        ref_post = env.delete('response.post')

        q = Query.new(Model::Post)
        q.deleted_at_table_names = %w( posts )

        q.query_conditions << "posts.user_id = ?"
        q.query_bindings << env['current_user'].id

        q.query_conditions << "posts.public_id = ?"
        q.query_bindings << ref_post.public_id

        authorizer = Authorizer.new(env)
        if env['current_auth'] && authorizer.auth_candidate
          unless authorizer.auth_candidate.read_all_types?
            _read_type_ids = Model::Type.find_types(authorizer.auth_candidate.read_types).inject({:base => [], :full => []}) do |memo, type|
              if type.fragment.nil?
                memo[:base] << type.id
              else
                memo[:full] << type.id
              end
              memo
            end

            q.query_conditions << ["OR",
              "posts.public = true",
              ["AND",
                "posts.entity_id = ?",
                ["OR",
                  "posts.type_base_id IN ?",
                  "posts.type_id IN ?"
                ]
              ]
            ]
            q.query_bindings << env['current_user'].entity_id
            q.query_bindings << _read_type_ids[:base]
            q.query_bindings << _read_type_ids[:full]
          end
        else
          q.query_conditions << "posts.public = true"
        end

        q.sort_columns = ["posts.version_received_at DESC"]

        q.limit = Feed::DEFAULT_PAGE_LIMIT

        versions = q.all

        env['response'] = {
          :versions => versions.map { |post| post.version_as_json(:env => env).merge(:type => post.type) }
        }

        if env['params']['profiles']
          env['response'][:profiles] = MetaProfile.new(env, versions).profiles(
            env['params']['profiles'].split(',') & ['entity']
          )
        end

        env['response.headers'] = {}
        env['response.headers']['Content-Type'] = VERSIONS_CONTENT_TYPE

        if env['REQUEST_METHOD'] == 'HEAD'
          env['response.headers']['Count'] = q.count.to_s
        end

        env
      end
    end

  end
end
