module TentD
  module Utils

    def self.hex_digest(io)
      digest = Digest::SHA512.new
      while buffer = io.read(1024)
        digest << buffer
      end
      io.rewind
      digest.hexdigest[0...64]
    end

  end
end
