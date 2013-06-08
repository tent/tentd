module TentD

  class Refs
    MAX_REFS_PER_POST = 5.freeze

    def self.fetch(current_user, *posts, max_refs)
      max_refs = [MAX_REFS_PER_POST, max_refs.to_i].min
      return [] if max_refs == 0

      q = Query.new(Model::Post)

      q.query_conditions << "#{q.table_name}.user_id = ?"
      q.query_bindings << current_user.id

      ref_conditions = []
      posts.each do |post|
        next unless post.refs.to_a.any?

        post.refs.slice(0, max_refs).each do |ref|
          ref_conditions << ["AND",
            "#{q.table_name}.public_id = ?",
            ref['entity'].nil? ? "#{q.table_name}.entity_id = ?" : "#{q.table_name}.entity = ?"
          ]

          q.query_bindings << ref['post']
          q.query_bindings << (ref['entity'] || post.entity_id)
        end
      end
      return [] if ref_conditions.empty?
      q.query_conditions << ["OR"].concat(ref_conditions)

      q.all.uniq
    end

  end

end
