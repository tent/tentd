# Source: https://gist.github.com/1407841
module Sequel
  module Plugins
    # The paranoia plugin creates hooks that automatically set deleted
    # timestamp fields.  The field name used is configurable, and you
    # can also set whether to overwrite existing deleted timestamps (false
    # by default). Adapted from Timestamps plugin.
    # 
    # Usage:
    #
    #   # Soft deletion for all model instances using +deleted_at+
    #   # (called before loading subclasses)
    #   Sequel::Model.plugin :paranoia
    #
    #   # Paranoid Album instances, with custom column names
    #   Album.plugin :paranoia, :deleted_at=>:deleted_time
    #
    #   # Paranoid Artist instances, forcing an overwrite of the deleted
    #   # timestamp
    #   Album.plugin :paranoia, :force=>true
    module Paranoia
      # Configure the plugin by setting the avialable options.  Note that
      # if this method is run more than once, previous settings are ignored,
      # and it will just use the settings given or the default settings.  Options:
      # * :deleted_at - The field to hold the deleted timestamp (default: :deleted_at)
      # * :force - Whether to overwrite an existing deleted timestamp (default: false)
      def self.configure(model, opts={})
        model.instance_eval do
          @deleted_timestamp_field = opts[:deleted_at]||:deleted_at
          @deleted_timestamp_overwrite = opts[:force]||false
        end
        model.class_eval do
          set_dataset filter(@deleted_timestamp_field => nil)
        end
      end

      module ClassMethods
        # The field to store the deleted timestamp
        attr_reader :deleted_timestamp_field

        # Whether to overwrite the deleted timestamp if it already exists
        def deleted_timestamp_overwrite?
          @deleted_timestamp_overwrite
        end

        # Copy the class instance variables used from the superclass to the subclass
        def inherited(subclass)
          super
          [:@deleted_timestamp_field, :@deleted_timestamp_overwrite].each do |iv|
            subclass.instance_variable_set(iv, instance_variable_get(iv))
          end
        end

        def with_deleted
          dataset.unfiltered
        end
      end

      module InstanceMethods
        # Rather than delete the object, update its deleted timestamp field.
        def delete
          set_deleted_timestamp
        end

        private

        # If the object has accessor methods for the deleted timestamp field, and
        # the deleted timestamp value is nil or overwriting it is allowed, set the
        # deleted timestamp field to the time given or the current time.
        def set_deleted_timestamp(time=nil)
          field = model.deleted_timestamp_field
          meth = :"#{field}="
          if respond_to?(field) && respond_to?(meth) && (model.deleted_timestamp_overwrite? || send(field).nil?)
            self.send(meth, time||=Sequel.datetime_class.now)
            self.save
          end
        end
      end
    end
  end
end
