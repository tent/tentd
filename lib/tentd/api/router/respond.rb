module TentD
  class API
    module Router
      class Respond
        def initialize
          @serialize = SerializeResponse.new
          @stream = StreamResponse.new
        end
        
        def call(env)
          if @stream.matches?(env)
            @stream.call(env)
          else
            @serialize.call(env)
          end
        end
      end
    end
  end
end