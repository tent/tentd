module TentD
  module Model
    module Serializable
      def as_json(options = {})
        attributes = super(:only => self.class.public_attributes)
        attributes.merge!(:permissions => permissions_json(options[:permissions])) if respond_to?(:permissions_json)
        attributes[:id] = respond_to?(:public_id) ? public_id : id

        if options[:app]
          [:created_at, :updated_at, :published_at, :received_at].each { |key|
            attributes[key] = send(key) if respond_to?(key)
          }
        end

        [:published_at, :updated_at, :created_at, :received_at].each do |key|
          attributes[key] = attributes[key].to_time.to_i if attributes[key].respond_to?(:to_time)
        end

        mac_fields = [:mac_key_id, :mac_key, :mac_algorithm]
        if options[:mac] && mac_fields.select { |k| respond_to?(k) }.size == mac_fields.size
          mac_fields.each { |k| attributes[k] = send(k) }
        end

        if options[:groups] && respond_to?(:groups)
          attributes[:groups] = groups.to_a.uniq
        end

        attributes
      end
    end
  end
end
