module TentD
  module Utils

    def self.random_id
      SecureRandom.urlsafe_base64(16)
    end

    def self.hex_digest(io)
      io = StringIO.new(io) if String === io

      digest = Digest::SHA512.new
      while buffer = io.read(1024)
        digest << buffer
      end
      io.rewind
      digest.hexdigest[0...64]
    end

    module Hash
      extend self

      def slice(hash, *keys)
        keys.each_with_object(hash.class.new) { |k, new_hash|
          new_hash[k] = hash[k] if hash.has_key?(k)
        }
      end

      def slice!(hash, *keys)
        hash.replace(slice(hash, *keys))
      end
    end

  end
end
