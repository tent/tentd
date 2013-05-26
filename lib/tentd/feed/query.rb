module TentD
  class Feed

    class Query
      attr_reader :model, :table_name, :select_columns, :sort_columns, :query_conditions, :query_bindings
      attr_accessor :sort_order, :limit
      def initialize(model)
        @model = model
        @table_name = model.table_name
        @query_conditions = []
        @query_bindings = []

        @select_columns = '*'
        @sort_columns = nil
        @sort_order = 'ASC'
      end

      def select_columns=(columns)
        @select_columns = Array(columns).map(&:to_s).join(',')
      end

      def sort_columns=(columns)
        @sort_columns = Array(columns).map(&:to_s).join(',')
      end

      def build_query_conditions(options = {})
        sep = options[:conditions_sep] || 'AND'

        query_conditions.map do |c|
          if c.kind_of?(Array) && ['OR', 'AND'].include?(c.first)
            c = c.dup
            c_sep = c.shift
            if c.size > 1
              "(#{c.join(" #{c_sep} ")})"
            else
              c.first
            end
          else
            c
          end
        end.join(" #{sep} ")
      end

      def to_sql(options = {})
        q = ["SELECT #{select_columns} FROM #{table_name}"]

        if query_conditions.any?
          q << "WHERE #{build_query_conditions(options)}"
        end

        q << "ORDER BY #{sort_columns} #{sort_order}" if sort_columns
        q << "LIMIT #{limit.to_i}" if limit

        q.join(' ')
      end

      def all(options = {})
        model.with_sql(to_sql(options), *query_bindings)
      end
    end

  end
end
