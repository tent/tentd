module TentD
  module Model
    module TypeProperties
      def self.included(base)
        base.class_eval do
          property :type, String
          property :type_view, String, :default => lambda { |m,p|
            TentType.new(m.type).view || 'full' unless m.type == 'all'
          }
          property :type_version, String, :default => lambda { |m, p|
            TentType.new(m.type).version.to_s unless m.type == 'all'
          }

          before :save do
            self.type = TentType.new(type).uri unless type == 'all'
          end
        end
      end
    end
  end
end
