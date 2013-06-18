module TentD

  class Query
    attr_reader :model, :table_name, :select_columns, :joins, :sort_columns, :query_conditions, :query_bindings
    attr_accessor :limit, :reverse_sort
    def initialize(model)
      @model = model
      @table_name = model.table_name
      @query_conditions = []
      @query_bindings = []

      @select_columns = "#{table_name}.*"
      @joins = []
      @sort_columns = nil
      @reverse_sort = false
    end

    def select_columns=(columns)
      @select_columns = Array(columns).map(&:to_s).join(',')
    end

    def sort_columns=(columns)
      @sort_columns = Array(columns).map(&:to_s).join(', ')
    end

    def join(sql)
      joins << sql
    end

    def qualify(column)
      "#{table_name}.#{column}"
    end

    def build_query_conditions(options = {})
      sep = options[:conditions_sep] || 'AND'

      query_conditions.map do |c|
        _build_conditions(c)
      end.join(" #{sep} ")
    end

    def _build_conditions(conditions)
      conditions = conditions.dup
      if conditions.kind_of?(Array) && ['OR', 'AND'].include?(conditions.first)
        sep = conditions.shift
        if conditions.size > 1
          conditions.map! {|c| c.kind_of?(Array) ? _build_conditions(c) : c }
          "(#{conditions.join(" #{sep} ")})"
        else
          if conditions.first.kind_of?(Array)
            _build_conditions(conditions.first)
          else
            conditions.first
          end
        end
      else
        conditions
      end
    end

    def to_sql(options = {})
      if options[:count]
        q = ["SELECT COUNT(#{options[:select_columns] || select_columns}) AS tally FROM #{table_name}"].concat(joins)
      else
        q = ["SELECT #{options[:select_columns] || select_columns} FROM #{table_name}"].concat(joins)
      end

      if query_conditions.any?
        q << "WHERE #{build_query_conditions(options)}"
      end

      unless options[:count]
        if sort_columns
          if reverse_sort
            q << "ORDER BY #{sort_columns.gsub("DESC", "ASC")}"
          else
            q << "ORDER BY #{sort_columns}"
          end
        end

        q << "LIMIT #{options[:limit] || limit.to_i}" if limit
      end

      q.join(' ')
    end

    def count
      model.with_sql(to_sql(:select_columns => "#{table_name}.id", :count => true), *query_bindings).to_a.first[:tally]
    end

    def any?
      model.with_sql(to_sql(:select_columns => "#{table_name}.id", :limit => 1), *query_bindings).to_a.any?
    end

    def first
      model.with_sql(to_sql(:limit => 1), *query_bindings).to_a.first
    end

    def all(options = {})
      models = model.with_sql(to_sql(options), *query_bindings).to_a
      if reverse_sort
        models.reverse
      else
        models
      end
    end
  end

end
