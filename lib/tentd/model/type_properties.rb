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
            if type == 'all'
              self.type_version = nil
              self.type_view = 'full'
            else
              t = TentType.new(type)
              self.type = t.uri
              self.type_version ||= t.version
              self.type_view ||= (t.view || 'full')
            end
          end
        end
      end

      def full_type
        "#{type}/v#{type_version}"
      end
    end
  end
end
