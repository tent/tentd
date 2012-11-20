module TentD
  module Model
    module Serializable
      def attributes(options = {})
        cols = columns.dup
        cols.reject! { |k| options[:except].include?(k) } if options[:except].kind_of?(Array)
        cols.select! { |k| options[:only].include?(k) } if options[:only].kind_of?(Array)
        cols.inject({}) { |memo, column| memo[column] = send(column); memo }
      end

      def as_json(options = {})
        attrs = attributes(options).select { |k,v| self.class.public_attributes.include?(k) }
        attrs.merge!(:permissions => permissions_json(options[:permissions])) if respond_to?(:permissions_json)
        attrs[:id] = respond_to?(:public_id) ? public_id : id

        if options[:app]
          [:created_at, :updated_at, :published_at, :received_at].each { |key|
            attrs[key] = send(key) if respond_to?(key)
          }
        end

        [:published_at, :updated_at, :created_at, :received_at].each do |key|
          attrs[key] = attrs[key].to_time.to_i if attrs[key].respond_to?(:to_time)
        end

        mac_fields = [:mac_key_id, :mac_key, :mac_algorithm]
        if options[:mac] && mac_fields.select { |k| respond_to?(k) }.size == mac_fields.size
          mac_fields.each { |k| attrs[k] = send(k) }
        end

        if options[:groups] && respond_to?(:groups)
          attrs[:groups] = groups.to_a.uniq
        end

        if self.class.associations.include?(:attachments)
          if options[:view] && respond_to?(:views) && (conditions = (views[options[:view]] || {})['attachments'])
            conditions.map! { |c| c.slice('category', 'name', 'type').inject({}) { |m,(k,v)| m[k.to_sym] = v; m } }.reject! { |c| c.empty? }

            # TODO: this should be a single query
            attrs[:attachments] = conditions.inject(nil) { |memo, c|
              q = attachments_dataset.where(c)
              memo ? memo += q.all : q.all
            }.sort_by { |a| a.id }
          else
            attrs[:attachments] = attachments.map { |a| a.as_json } unless options[:view] == 'meta'
          end
        end

        if !!options[:view] && respond_to?(:views) && respond_to?(:content)
          if keypaths = (views[options[:view]] || {})['content']
            attrs[:content] = keypaths.inject({}) do |memo, keypath|
              pointer = JsonPatch::HashPointer.new(content, keypath)
              memo[pointer.keys.last] = pointer.exists? ? pointer.value : nil
              memo
            end
          elsif options[:view] == 'meta'
            attrs.delete(:content)
          elsif options[:view] != 'full'
            attrs[:content] = {}
          end
        end

        attrs
      end

      def to_json(options = {})
        as_json(options).to_json
      end
    end
  end
end
