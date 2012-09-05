module TentD
  module Model
    module Serializable
      def as_json(options = {})
        attributes = super(:only => self.class.public_attributes)
        attributes.merge!(:permissions => permissions_json(options[:permissions])) if respond_to?(:permissions_json)

        [:published_at, :updated_at].each do |key|
          attributes[key] = attributes[key].to_time.to_i if attributes[key].respond_to?(:to_time)
        end

        attributes
      end
    end
  end
end
