require 'dm-core/query'

module DataMapper
  class Query
    private

    def get_relative_position(offset, limit)
      self_offset = self.offset
      self_limit  = self.limit
      new_offset  = self_offset + offset

      if limit < 0 || offset < 0
        raise RangeError, "offset #{offset} and limit #{limit} are outside allowed range"
      end

      return new_offset, limit
    end
  end
end
