require 'fog'

module TentD
  module Model

    class Attachment

      class << self
        attr_accessor :fog_adapter, :namespace
      end

      def self.connection
        @connection ||= Fog::Storage.new(fog_adapter)
      end

      def self.directory
        @directory ||= begin
          connection.directories.get(namespace) || connection.directories.create(:key => namespace)
        end
      end

      def self.find_by_digest(digest)
        find(:digest => digest)
      end

      def self.find(attrs)
        if file = directory.files.head(attrs[:digest])
          new(file)
        else
          nil
        end
      end

      def self.create(attrs)
        new(directory.files.create(
          :body => attrs[:data],
          :key => attrs[:digest]
        ))
      end

      def self.find_or_create(attrs)
        find(attrs) || create(attrs)
      end

      def initialize(file)
        @file = file
      end

      def id
        nil # for posts_attachments record
      end

      def digest
        @file.key
      end

      def size
        @file.content_length
      end

      def data(&block)
        @file.collection.get(@file.key, &block)
      end
      alias each data

      def read
        data.body
      end

    end

  end
end
