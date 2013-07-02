module TentD
  module Model

    class PGLargeObject
      CHUNK_SIZE = 1_000_000.freeze # 1 MB

      def self.find(connection_pool, oid)
        object = new(connection_pool, oid)
        return nil unless object.exists?
        object
      end

      def self.create(connection_pool, io)
        object = new(connection_pool)
        object.create(io)
        object
      end

      attr_accessor :oid
      def initialize(connection_pool, oid=nil)
        @connection_pool, @oid = connection_pool, oid
      end

      def connection
        @connection_pool.available_connections.first
      end

      def exists?
        return unless @oid
        connection.transaction do
          descriptor = connection.lo_open(@oid, PG::INV_READ)
          connection.lo_close(descriptor)
        end
        true
      rescue PG::Error
      end

      def each(&block)
        return unless @oid
        connection.transaction do
          descriptor = connection.lo_open(@oid, PG::INV_READ)
          while chunk = connection.lo_read(descriptor, CHUNK_SIZE)
            yield(chunk)
          end
          connection.lo_close(descriptor)
        end
      end

      def read
        return unless @oid
        data = ""
        each { |chunk| data << chunk }
        data
      end

      def create(io)
        connection.transaction do
          @oid = connection.lo_creat(PG::INV_WRITE)
          descriptor = connection.lo_open(oid, PG::INV_WRITE)
          while chunk = io.read(CHUNK_SIZE)
            connection.lo_write(descriptor, chunk)
          end
          io.rewind if io.respond_to?(:rewind)
          connection.lo_close(descriptor)
        end
        @oid
      end

      def destroy
        connection.transaction do
          connection.lo_unlink(@oid)
        end
        true
      rescue PG::Error
      end
    end

    module SequelPGLargeObject
      def self.included(model)
        model.extend(ClassMethods)
      end

      module ClassMethods
        # each name should have an integer column of the same name with "_oid" suffix
        def pg_large_object(*names)
          names.each do |name|
            define_method name do
              oid = self[:"#{name}_oid"]

              Model::PGLargeObject.find(self.db.pool, oid)
            end

            define_method "#{name}=" do |io|
              object = Model::PGLargeObject.create(self.db.pool, io)
              self["#{name}_oid"] = object.oid
              object
            end
          end
        end
      end
    end

  end
end
