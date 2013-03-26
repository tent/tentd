module TentD
  class API

    module SerializeResponse
      def self.call(env)
        [201, {}, []]
      end
    end

  end
end
