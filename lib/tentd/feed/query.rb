module TentD
  class Feed

    class Query
      attr_reader :model, :table_name, :select_columns, :sort_columns, :query_conditions, :query_bindings
      attr_accessor :sort_order
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

      def all
        q = ["SELECT #{select_columns} FROM #{table_name}"]
        q << "WHERE #{query_conditions.join(' AND ')}" if query_conditions.any?
        q << "ORDER BY #{sort_columns} #{sort_order}" if sort_columns
        q = q.join(' ')

        model.with_sql(q, *query_bindings)
      end
    end

  end
end
